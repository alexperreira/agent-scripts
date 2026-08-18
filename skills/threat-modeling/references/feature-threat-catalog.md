# Feature Threat Catalog

Loaded by `threat-modeling` when the feature under design matches one of these types. Each
list is a starting enumeration, not a complete one — run STRIDE against the actual design as
well.

---

## Authentication & Session Features

- Credential brute force — rate limiting on login endpoint?
- Session fixation — session ID regenerated on privilege change?
- Token leakage — JWTs in URLs, logs, or error responses?
- Password reset flow — token entropy sufficient? Time-limited? Single-use?
- OAuth misuse — `state` parameter validated? Redirect URI pinned?

Depth on all of these lives in `auth-authorization-audit`.

---

## Data Access / CRUD Features

- IDOR (Insecure Direct Object Reference) — ownership check on every record fetch/mutate?
- Mass assignment — are all writable fields explicitly allowlisted?
- Horizontal privilege escalation — can UserA modify UserB's data?
- Vertical privilege escalation — can a regular user reach an admin endpoint?
- Soft-delete bypass — can deleted records be accessed by manipulating filters?

The ownership-scoped query pattern and the mass-assignment allowlist are owned by
`auth-authorization-audit`.

---

## File Upload Features

- File type validation — MIME type checked server-side (not just extension)?
- Size limit — enforced before processing, not after?
- Path traversal — filename sanitized before use in filesystem operations?
- Malicious content — files served directly to other users? (XSS via SVG/HTML upload)
- Storage permissions — uploaded files publicly accessible by default?

---

## Webhook / Inbound Integration Features

- Signature verification — HMAC or equivalent checked before processing payload?
- Replay attacks — timestamp window enforced? Idempotency key stored?
- Payload validation — schema validated before acting on any field?
- Denial of service — payload size capped? Processing rate limited?

Implementation lives in `webhook-security`.

---

## Background Jobs / Async Processing

- Input trust — job payloads treated as untrusted input and validated?
- Privilege — job runs with minimum required permissions?
- Failure handling — failed jobs don't leave data in inconsistent state?
- Enumeration — job IDs guessable? Can a user poll another user's job?
