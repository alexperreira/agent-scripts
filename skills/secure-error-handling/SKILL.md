---
name: secure-error-handling
description: >
  Ensures production error payloads never leak stack traces, internal paths, DB details, or
  user PII. Use this skill whenever Alex is implementing error handling middleware, reviewing
  API error responses, asking "what should I return on a 500", "is it safe to show this error",
  or building a new API surface. Also trigger proactively when a code review finds bare
  `catch (e) { res.json({ error: e.message }) }` patterns — one of the most common ways
  internal system details leak to attackers. Error messages are a free reconnaissance tool
  for attackers unless deliberately locked down.
---

# Secure Error Handling

Ensures errors are handled at the right level, logged with enough context for debugging,
and sanitized before reaching the client.

A single stack trace in a 500 response can expose file paths, DB schema, library versions,
and internal architecture — all useful to an attacker.

---

## Core Principles

1. **Use error types to control client visibility.** Operational errors (not found, validation
   failed, unauthorized) are safe to describe to clients. Programmer errors (unhandled
   exceptions, type errors) always return a generic 500.

2. **The client-facing error body contains exactly `code`, `message`, optional `details`
   (validation only), and `meta.requestId`. Nothing else ships.** (Envelope shape owned by
   api-contract-design.) Full context — stack, DB error string, file paths — goes to the log,
   correlated by the same `requestId`.

---

## Error Architecture

**The two-branch rule.** Every error reaching the global handler takes exactly one of two paths:

| Branch | Condition | Client gets | Log level |
|---|---|---|---|
| Operational | `err instanceof AppError` | The error's own `code`, `message`, `statusCode`, plus `details` for validation | `warn` |
| Programmer / unknown | anything else | The canonical `INTERNAL_ERROR` 500 payload | `error`, with full stack |

The operational error classes: `AppError` (base), `NotFoundError`, `ValidationError`,
`ForbiddenError`, `UnauthorizedError`.

**For the full `AppError` class hierarchy and the Express `errorHandler` implementation, read
`references/express-error-handler.md` when writing or reviewing that middleware.**

---

## Common Anti-Patterns

```ts
// ❌ Raw error message in response — leaks DB details, file paths
res.status(500).json({ error: err.message });

// ❌ Stack trace in response
res.status(500).json({ error: err.stack });

// ❌ Swallowed error — failure is invisible
try {
  await doThing();
} catch (e) {
  console.log(e); // logged but not re-thrown, caller proceeds as if success
}

// ❌ Overly broad catch hides bugs
try {
  return processPayment(data);
} catch {
  return { success: false }; // TypeError from a bug looks like a declined payment
}
```

---

## Logging Checklist

What to include in server-side error logs:
- [ ] `requestId` — links log to client-facing response
- [ ] `userId` / `sessionId` — who triggered it (if authenticated)
- [ ] `path` and `method` — what endpoint
- [ ] `error.message` and `error.stack` — full internal detail
- [ ] Timestamp

Request bodies are logged only after passing through this field allowlist.

---

## Secure Error Handling Checklist

- [ ] `app.use(errorHandler)` is the last `app.use` in the server entrypoint, and
      `grep -rn "res.status(5" src/` returns only that handler
- [ ] `AppError` subclasses used for all operational errors
- [ ] Every 500 response body is byte-identical to the canonical internal-error payload
- [ ] All async route handlers wrapped in try/catch or async error middleware
- [ ] Error logs include `requestId` for correlation
- [ ] Every 404 body is identical whether the resource is missing or not owned
      (see auth-authorization-audit)
- [ ] Validation errors return 400 with field detail
- [ ] Error log messages carry IDs, not PII
- [ ] Unhandled promise rejection and uncaught exception handlers installed at process level

---

If every route already routes through the global handler and every 500 is the canonical
payload, say so clearly — don't manufacture findings.
