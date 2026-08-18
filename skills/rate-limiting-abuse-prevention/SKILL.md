---
name: rate-limiting-abuse-prevention
description: >
  Designs throttling strategy: per-user, per-IP, per-endpoint, with consistent 429 envelopes
  and backoff guidance. Use this skill whenever Alex is designing a public or authenticated
  API endpoint, adding a login or signup flow, building a webhook receiver, or asks "how do I
  prevent abuse", "should I rate limit this", "what happens if someone hammers this endpoint".
  Also trigger proactively when a task doc introduces any endpoint that: accepts unauthenticated
  requests, triggers an email or SMS, calls a paid third-party API, or performs an expensive
  operation. An unprotected endpoint is an availability and cost vulnerability.
---

# Rate Limiting & Abuse Prevention

Designs throttling strategy for API endpoints, auth flows, and resource-intensive operations.

---

## Core Principles

1. **Every public surface needs a rate limit.** Unauthenticated endpoints with no throttle
   are DoS vulnerabilities. Authenticated endpoints with no throttle enable abuse and cost attacks.

2. **Match the limit to the threat.** Login endpoints need tight per-IP limits to prevent
   brute force. Bulk export endpoints need per-user limits to prevent scraping. Webhook
   receivers need payload size limits to prevent amplification.

3. **Limit at multiple levels.** IP-based limits catch unauthenticated abuse. User-based
   limits catch authenticated abuse. Both are necessary.

4. **429 responses must include retry guidance.** A 429 without a `Retry-After` header is
   unhelpful to legitimate clients and has no effect on bad actors. Always include it.

---

## Limit Tiers by Endpoint Type

| Endpoint type | Recommended limits | Rationale |
|---|---|---|
| Login / signup | 5 req/min per IP, 10 req/hr per IP | Brute force prevention |
| Password reset request | 3 req/hr per IP, 3 req/hr per email | Prevents reset flooding |
| Email / SMS send | 5 req/hr per user | Cost and spam prevention |
| Standard authenticated API | 100–300 req/min per user | Normal usage headroom |
| Expensive operation (AI, export, report) | 10–20 req/min per user | Cost and resource protection |
| Unauthenticated read endpoint | 30 req/min per IP | Scraping deterrence |
| Webhook receiver | 1000 req/min per source IP + payload size cap | Amplification prevention |

Raise a tier only against a measured p99 from production traffic, never against a guess.

---

## Implementation Patterns

### Using a sliding window counter (Redis)

```ts
import { redis } from './redis';

async function checkRateLimit(
  key: string,         // e.g. `rate:login:ip:${ip}`
  limit: number,       // max requests
  windowSeconds: number
): Promise<{ allowed: boolean; retryAfter?: number }> {
  const now = Date.now();
  const member = `${now}-${randomUUID()}`;

  // Single atomic round trip. Separate zremrangebyscore/zcard/zadd calls are a TOCTOU race:
  // under a burst, N concurrent callers each observe count < limit and all pass, so the
  // limit fails at exactly the moment it matters most.
  const [allowed, oldestScore] = await redis.eval(
    `
    local now    = tonumber(ARGV[1])
    local window = tonumber(ARGV[2])
    local limit  = tonumber(ARGV[3])
    local member = ARGV[4]

    redis.call('ZREMRANGEBYSCORE', KEYS[1], 0, now - window)
    local count = redis.call('ZCARD', KEYS[1])

    if count >= limit then
      local oldest = redis.call('ZRANGE', KEYS[1], 0, 0, 'WITHSCORES')
      return { 0, oldest[2] }
    end

    redis.call('ZADD', KEYS[1], now, member)
    redis.call('PEXPIRE', KEYS[1], window)
    return { 1, '0' }
    `,
    1,
    key,
    String(now),
    String(windowSeconds * 1000),
    String(limit),
    member,
  ) as [number, string];

  if (!allowed) {
    const retryAfter = Math.ceil((Number(oldestScore) + windowSeconds * 1000 - now) / 1000);
    return { allowed: false, retryAfter: Math.max(retryAfter, 1) };
  }
  return { allowed: true };
}
```

**Atomicity is the whole point.** A rate limiter built from separate read-then-write calls
enforces the limit under normal traffic and fails open under a burst — which is the only traffic
it exists to stop. Use a Lua script (above), a `MULTI`/`EXEC` transaction, or a library that does
one of the two. `Math.random()` in the member key is also replaced with `randomUUID()`: two
requests in the same millisecond can collide on a random float, silently overwriting one entry
and undercounting.

### 429 Response Envelope

Every 429 sets these headers:
- `Retry-After` (seconds until the client may retry)
- `X-RateLimit-Limit` (the limit that was hit)
- `X-RateLimit-Remaining: 0`

The body carries error code `RATE_LIMITED`, a human-readable message, and `meta.requestId`
(shape owned by api-contract-design).

### Layered limits (IP + user)

```ts
// Check IP limit first (unauthenticated gate)
const ipCheck = await checkRateLimit(`rate:${endpoint}:ip:${ip}`, 30, 60);
if (!ipCheck.allowed) return send429(ipCheck.retryAfter);

// Then check user limit (authenticated gate)
if (session?.userId) {
  const userCheck = await checkRateLimit(`rate:${endpoint}:user:${session.userId}`, 100, 60);
  if (!userCheck.allowed) return send429(userCheck.retryAfter);
}
```

---

## Abuse Prevention Patterns

### Idempotency keys for retries
Expensive or side-effectful operations (payments, email sends) should accept an
`Idempotency-Key` header. Store processed keys in Redis with a TTL. Duplicate requests
return the cached result without re-executing.

### Payload size limits
This skill owns payload and body size caps. Cap request body size at the application layer,
not just at the reverse proxy:

```ts
// Express
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));
```

For file uploads, enforce at the storage middleware layer before writing to disk.

---

## Rate Limiting Checklist

- [ ] Login and signup endpoints: per-IP limit set
- [ ] Password reset: per-IP and per-email limit set
- [ ] Any endpoint that sends email/SMS: per-user limit set
- [ ] Any expensive or AI-powered endpoint: per-user limit set
- [ ] All public (unauthenticated) endpoints: per-IP limit set
- [ ] 429 responses include `Retry-After` header
- [ ] Rate limit keys are namespaced by endpoint (not shared across routes)
- [ ] Limits read from config so each environment can set its own values
- [ ] Login and password-reset failures return one identical response for unknown-user and
      wrong-password (see auth-authorization-audit)
- [ ] Request body size capped at application layer

---

If every surface in the change already carries a limit matched to its threat, say so clearly —
don't manufacture findings.
