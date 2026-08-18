---
name: input-validation-sanitization
description: >
  Enforces validation at every trust boundary: API inputs, DB writes, file uploads, and
  user-generated content. Use this skill whenever Alex is designing or reviewing an API
  endpoint that accepts user input, a form, a file upload, a webhook handler, or asks
  "how should I validate this", "is this input safe", "how do I prevent injection here",
  or "what do I need to sanitize". Also trigger proactively when a task doc introduces
  any new user-facing input surface. Every trust boundary is an injection vector until
  proven otherwise — validate at entry, not at use.
---

# Input Validation & Sanitization

Enforces correct validation at every trust boundary. Untrusted input that reaches business
logic, the DB, or the filesystem without validation is the root cause of injection attacks,
data corruption, and undefined behavior.

---

## Core Principles

1. **Parse, don't validate.** Transform input into a typed, constrained value the moment it
   enters the system — in the route handler or middleware, before any business logic runs.
   After parsing, the rest of the codebase works with the parsed type, not the raw input.

2. **Allowlist, not blocklist.**

3. **Fail closed.** If validation is ambiguous or the schema is unclear, reject the input.
   Unexpected input is rejected, not coerced.

4. **Sanitize for output, not input.** Store the raw content; strip at render time for the
   target output context (HTML, JSON, SQL). Sanitizing on input destroys data and still
   doesn't protect every output context.

---

## Validation by Input Type

### Request Body (JSON APIs)

Use a schema validation library. For TypeScript: Zod. For Python: Pydantic.

```ts
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email().max(254),
  displayName: z.string().min(1).max(100).trim(),
  role: z.enum(['viewer', 'editor']), // user-settable roles only; 'admin' is assigned server-side
  age: z.number().int().min(13).max(120).optional(),
});

// In handler — parse throws on invalid input
const body = CreateUserSchema.parse(req.body);
// body is now fully typed and safe to use
```

Return `400 VALIDATION_ERROR` with field-level detail on failure (see API contract skill).

### Path & Query Parameters

```ts
const ParamsSchema = z.object({
  userId: z.string().regex(/^usr_[a-z0-9]{16}$/), // pin ID format
});

const QuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  cursor: z.string().optional(),
});
```

Every path and query param passes through its schema before it reaches a DB query or a
filesystem call.

### File Uploads

```ts
// Validate before processing
const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_SIZE_BYTES = 5 * 1024 * 1024; // 5MB

if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
  throw new ValidationError('File type not allowed');
}
if (file.size > MAX_SIZE_BYTES) {
  throw new ValidationError('File too large');
}

// Sanitize filename — the storage path uses a generated name, not the user's
const safeFilename = `${crypto.randomUUID()}.${getExtension(file.mimetype)}`;
```

The storage path is built from a generated UUID and a MIME-derived extension, so a hostile
filename has nowhere to land (path traversal). The MIME type is decided server-side by
sniffing content — the client-supplied `Content-Type` and the file extension are both
untrusted input.

### User-Generated Content (HTML / Rich Text)

For content that will be rendered as HTML (rich text editors, comments):

```ts
import DOMPurify from 'isomorphic-dompurify';

// Sanitize at render time, not storage time
const safeHtml = DOMPurify.sanitize(userContent, {
  ALLOWED_TAGS: ['p', 'b', 'i', 'em', 'strong', 'a', 'ul', 'ol', 'li'],
  ALLOWED_ATTR: ['href'], // the allowlist is the whole policy — onclick/onerror/style are simply absent
});
```

Store the raw content. Sanitize on output for the target context.

---

## Injection Prevention

**Before writing code that builds a SQL query, a filesystem path, or a subprocess invocation
from user input, read `references/injection-examples.md` for the safe form of each.**

The three target forms, in short:

| Sink | Safe form |
|---|---|
| SQL | Parameterized query, or an ORM with typed inputs |
| Filesystem path | `path.resolve` against the root dir, then prefix-check the result |
| Subprocess | `execFile` with an argv array — no shell |

---

## Validation Checklist

- [ ] All request bodies parsed through a schema (Zod / Pydantic / equivalent)
- [ ] Path and query params validated and typed before use
- [ ] String lengths bounded (min and max)
- [ ] Numeric ranges bounded (prevent overflow, negative-where-invalid)
- [ ] Enum fields parsed through an allowlist before the value reaches the DB
- [ ] File uploads: MIME type validated server-side, size capped, filename generated
- [ ] Request body size capped at the application layer (see rate-limiting-abuse-prevention)
- [ ] Every SQL call parameterized
- [ ] Every filesystem path `path.resolve`d and prefix-checked against its root
- [ ] Every subprocess launched via `execFile` with an argv array
- [ ] Rich text / HTML: sanitized at render time with allowlist library
- [ ] Validation errors return 400 with field-level detail
- [ ] Validation-failure logs carry field names and error codes only

---

If every input surface in the change already parses through a schema and every sink uses its
safe form, say so clearly — don't manufacture findings.
