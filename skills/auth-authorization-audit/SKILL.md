---
name: auth-authorization-audit
description: >
  Reviews auth flows for common failures: privilege escalation, broken access control, insecure
  session handling, and JWT pitfalls. Use this skill whenever Alex is building or reviewing
  authentication, authorization, login/logout flows, role-based access, JWT handling, OAuth
  integration, or asks "is this auth correct", "can users access each other's data", "is this
  token secure". Also trigger proactively when a task doc introduces a new endpoint, a new user
  role, or a new data access pattern — auth correctness must be verified at design time, not
  discovered in production. Broken access control is the #1 web vulnerability category.
---

# Auth & Authorization Audit

Reviews authentication and authorization implementations for the failures that actually occur
in production.

---

## Common Failure Patterns

Check for these first — they account for most real auth breaks.

| Pattern | What goes wrong |
|---|---|
| Auth middleware applied globally but excluded for new routes | New route ships without auth |
| `userId` taken from request body instead of session | Attacker spoofs their own ID |
| Admin check by email domain (`@company.com`) | Anyone with a matching email is admin |
| Permission check skipped in background jobs | Jobs process other users' data |
| GraphQL — auth on resolver but not on nested fields | Nested field exposes unauthorized data |
| Soft-deleted records not excluded from auth scope | Deleted users' data still accessible |

---

## Authentication Audit

### JWT Handling

```ts
// ❌ Algorithm confusion attack — accepts 'none' or attacker-specified algorithm
jwt.verify(token, secret); // if secret is a public key, attacker can use RS256 → HS256 trick

// ✅ Always pin the algorithm explicitly
jwt.verify(token, secret, { algorithms: ['HS256'] });

// ❌ Signing secret too short or predictable
const secret = 'mysecret'; // brute-forceable

// ✅ Minimum 256-bit random secret
// openssl rand -base64 32
```

JWT checklist:
- [ ] Algorithm pinned to an explicit list — `algorithms: ['HS256']` or equivalent
- [ ] Signing secret is high-entropy (32+ random bytes), rotatable (see secrets skill)
- [ ] `exp` claim always set — tokens expire
- [ ] `iss` and `aud` claims validated if tokens cross service boundaries
- [ ] Tokens travel in the `Authorization` header only
- [ ] Token payload carries only the user ID, email, and other non-sensitive claims

### Session Handling

- [ ] Session ID regenerated on privilege change (login, role elevation)
- [ ] Session invalidated server-side on logout (not just clearing the cookie)
- [ ] Session cookie flags: `HttpOnly`, `Secure`, `SameSite=Strict` or `Lax`
- [ ] Session TTL enforced server-side, not just by cookie expiry
- [ ] > 3 active sessions per user triggers oldest-session eviction, or the app documents why
      unlimited concurrent sessions is acceptable

### Password & Credential Handling

- [ ] Passwords hashed with Argon2id, bcrypt (cost >= 12), or scrypt
- [ ] Password reset tokens are high-entropy, time-limited (< 1hr), single-use
- [ ] Login endpoint rate-limited (see rate-limiting skill)
- [ ] Login failure returns one identical response — same status, same body, same timing —
      whether the account is unknown or the password is wrong
- [ ] `autocomplete="new-password"` on set-password and change-password fields, so the browser
      offers a generated password instead of autofilling the current one. (This is a UX and
      password-hygiene control. It does nothing against credential stuffing, which is server-side
      replay of breached credentials — rate limiting and breached-password checks are the
      defenses there.)

### Enumeration-safe login (owner of this pattern)

```ts
// ❌ Leaks whether the email exists
if (!user) return res.status(404).json({ error: 'User not found' });
if (!validPassword) return res.status(401).json({ error: 'Wrong password' });

// ✅ Identical response — attacker learns nothing
if (!user || !validPassword) {
  return res.status(401).json({ ok: false, error: { code: 'UNAUTHORIZED' } });
}
```

Same rule applies to password reset and signup: the response for "email is registered" and
"email is not registered" must be indistinguishable, including latency. When the user record
is missing, still run a dummy hash comparison so the timing matches.

---

## Authorization Audit

A valid JWT proves identity — it does not automatically grant permission to every resource.

### The IDOR Checklist

Insecure Direct Object Reference — the most common authorization bug. Check every data access:

```ts
// ❌ Fetches any record by ID — no ownership check
const doc = await db.documents.findUnique({ where: { id: params.id } });

// ✅ Scopes to authenticated user
const doc = await db.documents.findUnique({
  where: { id: params.id, ownerId: session.userId }
});
// Returns null if not found OR not owned — same 404 response either way
// (Don't reveal whether the resource exists at all)
```

For every `findUnique`, `findFirst`, `update`, `delete` call — ask:
- Is this scoped to the authenticated user or their organization?
- Could an attacker substitute a different ID and reach a different user's record?
- Does a 404 leak whether the resource exists?

### Role-Based Access Control

```ts
// ❌ Checks role but doesn't verify resource ownership
if (user.role === 'admin') return resource;

// ❌ Role check after data fetch — data already loaded
const resource = await db.get(id);
if (!user.canAccess(resource)) throw new ForbiddenError();
// Better, but resource was loaded regardless — use scoped query instead

// ✅ Gate at the query level
const resource = await db.get(id, { requiredRole: user.role });
```

Role audit checklist:
- [ ] Every endpoint declares its required role/permission explicitly
- [ ] Role checks happen before any data is fetched (not after)
- [ ] Admin endpoints are on a separate auth path or require additional verification
- [ ] Role assignment itself is protected — only admins can promote to admin
- [ ] Role is read from the server-side session record on every check

### Mass Assignment

```ts
// ❌ Passes raw request body to ORM — attacker can set any field
await db.users.update({ where: { id }, data: req.body });
// Attacker sends: { "role": "admin", "verified": true }

// ✅ Explicit allowlist of writable fields
const { displayName, bio, avatarUrl } = req.body;
await db.users.update({ where: { id }, data: { displayName, bio, avatarUrl } });
```

---

## OAuth / SSO Audit

- [ ] `state` parameter generated, stored server-side, and validated on callback
  (prevents CSRF against the OAuth flow)
- [ ] `redirect_uri` pinned to one exact value held server-side
- [ ] Authorization code exchanged server-side
- [ ] `code` is single-use — verify the provider enforces this
- [ ] Access tokens stored in memory or an httpOnly cookie

---

If every access path is scoped, every role check is server-side, and the token handling holds
up, say so clearly — don't manufacture findings.
