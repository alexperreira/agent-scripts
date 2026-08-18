---
name: webhook-security
description: >
  Signature verification, replay protection, idempotency design — covers Stripe, GitHub, and
  any inbound webhook. Use this skill whenever Alex is implementing a webhook receiver, adding
  a new inbound integration (Stripe, GitHub, Clerk, any third-party event source), or asks
  "how do I secure this webhook", "do I need to verify this", "what if the same event fires
  twice". Also trigger proactively when a task doc introduces any endpoint that receives
  inbound HTTP calls from a third-party service.
---

# Webhook Security

Secures inbound webhook receivers against spoofing, replay attacks, and duplicate processing.

An unverified webhook is an unauthenticated POST endpoint that can trigger any action your
handler performs. Any attacker can send a fake event. Signature verification is non-negotiable.

---

## Core Requirements

Every webhook receiver must implement all three:

1. **Signature verification** — proves the payload came from the declared sender
2. **Replay protection** — prevents a captured valid request from being re-sent later
3. **Idempotency** — ensures processing the same event twice has no additional effect

---

## Signature Verification

### Raw body requirement

**Critical:** Signature verification requires the raw, unparsed request body. Once a JSON body
is parsed and re-serialized, the byte sequence changes and the signature breaks.

```ts
// Express — get raw body BEFORE json middleware for webhook routes
app.use('/webhooks', express.raw({ type: 'application/json' }));
app.use(express.json()); // json middleware for all other routes
```

### Generic HMAC pattern

For any provider that sends an HMAC signature:

```ts
function verifyHmacSignature(
  payload: Buffer,
  receivedSig: string,
  secret: string,
  algorithm = 'sha256'
): boolean {
  const expected = createHmac(algorithm, secret).update(payload).digest('hex');
  try {
    return timingSafeEqual(Buffer.from(expected), Buffer.from(receivedSig));
  } catch {
    return false; // mismatched lengths throw — treat as invalid
  }
}
```

**Always use `timingSafeEqual`** — regular string comparison (`===`) leaks timing information
that can be used to forge signatures.

**When the receiver is for Stripe or GitHub, read `references/providers.md` for that
provider's handler — each has a quirk the generic pattern doesn't cover.**

---

## Replay Protection

Some providers (Stripe, Svix) include a timestamp in the signed payload and reject requests
outside a tolerance window (e.g. 5 minutes). For providers that don't:

```ts
// Check timestamp freshness manually
const eventTimestamp = event.timestamp; // from payload
const now = Math.floor(Date.now() / 1000);
const TOLERANCE_SECONDS = 300; // 5 minutes

if (Math.abs(now - eventTimestamp) > TOLERANCE_SECONDS) {
  logger.warn('Webhook replay attempt or clock skew', { eventTimestamp, now });
  return res.status(400).json({ error: 'Request expired' });
}
```

---

## Idempotency

The same event can be delivered more than once (provider retries on timeout, network issues).
Handlers must be idempotent.

```ts
import { redis } from './redis';

async function processWebhookEvent(event: WebhookEvent): Promise<void> {
  const dedupKey = `webhook:processed:${event.id}`;
  const DEDUP_TTL = 86400; // 24 hours

  // Check if already processed
  const alreadyProcessed = await redis.set(dedupKey, '1', 'EX', DEDUP_TTL, 'NX');
  if (!alreadyProcessed) {
    logger.info('Duplicate webhook event ignored', { eventId: event.id });
    return;
  }

  // Process event — safe to run exactly once
  await handleEvent(event);
}
```

The dedup key uses the provider's event ID (e.g. `evt_abc123` from Stripe). TTL should
exceed the provider's retry window (usually 24–72 hours).

---

## Response Timing

**Always return 200 immediately, process asynchronously.** Webhook providers retry on
non-2xx responses and on timeouts. Processing inline can:
- Time out if processing is slow (provider retries → duplicate processing)
- Cause cascading failures if a downstream dependency is slow

```ts
// ✅ Acknowledge first, process async
res.status(200).json({ received: true });
await queue.add('process-webhook', { event }); // or setImmediate, worker queue, etc.
```

---

## Webhook Security Checklist

- [ ] Raw body captured before JSON parsing for signature verification routes
- [ ] Signature verified with the provider SDK or HMAC before any payload field is read
- [ ] `timingSafeEqual` used for any manual HMAC comparison
- [ ] Timestamp freshness checked (replay window enforced)
- [ ] Event ID stored in Redis/DB to deduplicate retries
- [ ] Handler returns 200 immediately — processing is async
- [ ] Webhook secret read from the environment (see secrets-env-management)
- [ ] Separate webhook secret per environment (dev/staging/prod)
- [ ] Webhook endpoint carries no session auth by design — the signature is the authentication
- [ ] Payload size capped (see rate-limiting skill)
- [ ] Failed events logged with event ID for manual replay if needed

---

If the receiver already verifies, dedups, and acknowledges correctly, say so clearly — don't
manufacture findings.
