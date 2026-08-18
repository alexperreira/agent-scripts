---
name: api-contract-design
description: >
  Designs REST or GraphQL API contracts with consistent envelope formats, error codes, pagination
  patterns, and auth conventions. Use this skill whenever Alex is designing a new API endpoint or
  set of endpoints, asks "how should this API be structured", wants to review or critique an
  existing API shape, needs to define request/response types, or is building a feature that
  introduces a new client-server boundary. Also trigger proactively when a task doc or ADR
  involves adding routes, changing response shapes, or introducing a new resource — even if Alex
  doesn't say "API design" explicitly. Covers mobile-friendly patterns (Expo/React Native),
  versioning strategy, and the contract decisions that are painful to change after clients ship.
---

# API Contract Design

Produces API contracts — endpoint definitions, request/response shapes, error envelopes,
pagination conventions, and auth patterns — that are consistent, client-friendly, and safe to
evolve over time.

**This skill owns the error envelope shape.** The `{ ok, data|error, meta }` structure and the
error-code registry below are canonical; sibling security skills point here rather than
redefining them.

---

## Core Principles

1. **Contract first, implementation second.** Define the full request/response shape before
   writing any handler code. The contract is the source of truth — not the implementation.

2. **Design for the worst client.** Mobile clients (React Native/Expo) have stricter constraints
   than web: offline recovery, background sync, limited bandwidth, app store release cycles.
   Design for the mobile client and the web client gets it for free.

3. **Explicit over implicit.** Every error body carries `error.code`; every optional field
   serializes as explicit `null`.

4. **Version from day one.** Even if you never need v2, putting `/v1/` in the path costs nothing
   and buys everything. Retrofitting versioning after clients ship is painful.

5. **Auth strategy is decided by `adr`, not here.** This skill assumes auth is settled and
   focuses on how it surfaces in the contract (headers, token format, scope requirements per
   endpoint).

---

## Standard Response Envelope

**Wrap every response in `{ ok, data|error, meta }`** — success and error alike.

### Success

```json
{
  "ok": true,
  "data": { ... },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2026-03-16T14:00:00Z"
  }
}
```

- `ok: true` always present on success
- `data` contains the resource or result — never null on success
- `meta` carries request tracing info — always include `requestId` for debuggability
- For list endpoints, `data` is an array and pagination lives in `meta` (see below)

### Error

```json
{
  "ok": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable description safe to show in logs",
    "details": [
      { "field": "email", "issue": "Invalid format" }
    ]
  },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2026-03-16T14:00:00Z"
  }
}
```

- `ok: false` always present on error
- `error.code` is a SCREAMING_SNAKE_CASE machine-readable string — clients branch on this
- `error.message` is a fixed, human-authored string chosen per error code — safe for logs
- `error.details` is optional — use for field-level validation errors
- `meta` always present, same shape as success

**Never** include stack traces, file paths, DB error strings, or internal IDs in error responses.

---

## Standard Error Codes

Define a project-level error code registry. Seed it with these universals:

| Code | HTTP Status | Meaning |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Request shape or field value invalid |
| `UNAUTHORIZED` | 401 | Missing or invalid auth credentials |
| `FORBIDDEN` | 403 | Authenticated but not permitted |
| `NOT_FOUND` | 404 | Resource does not exist |
| `CONFLICT` | 409 | State conflict (e.g. duplicate, stale update) |
| `RATE_LIMITED` | 429 | Too many requests — include `Retry-After` header |
| `INTERNAL_ERROR` | 500 | Unexpected server error — never expose details |
| `SERVICE_UNAVAILABLE` | 503 | Dependency down or maintenance mode |

Project-specific codes extend this list. Document them in `docs/api-error-codes.md`.

---

## Pagination

Use cursor-based pagination for all list endpoints. Offset pagination breaks under concurrent
writes and doesn't scale.

### Request
```
GET /v1/resources?cursor=eyJpZCI6MTIzfQ&limit=20
```

- `cursor` — opaque base64 string encoding position (never expose raw DB IDs)
- `limit` — max items per page; enforce a server-side cap (e.g. 100)

### Response (`meta` block)
```json
"meta": {
  "requestId": "req_abc123",
  "timestamp": "2026-03-16T14:00:00Z",
  "pagination": {
    "hasNextPage": true,
    "nextCursor": "eyJpZCI6MTQ0fQ",
    "hasPreviousPage": false,
    "previousCursor": null,
    "totalCount": null
  }
}
```

- `totalCount` is nullable — only populate if cheap to compute; never do a COUNT(*) just for this
- Cursors are opaque to clients — they must not construct or parse them

---

## GraphQL

If the contract is GraphQL rather than REST, read `references/graphql.md` — it covers schema
conventions, mapping resolver errors onto the error-code registry above, and connection-style
pagination.

---

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| URL path segments | `kebab-case`, plural nouns | `/v1/workout-sessions` |
| URL path params | `camelCase` | `/v1/users/:userId` |
| Query params | `camelCase` | `?sortBy=createdAt` |
| JSON field names | `camelCase` | `"createdAt"`, `"userId"` |
| Error codes | `SCREAMING_SNAKE_CASE` | `"VALIDATION_ERROR"` |
| Resource IDs | Opaque strings (never expose raw DB integer IDs) | `"usr_abc123"` |

Prefixed IDs (`usr_`, `sess_`, `wod_`) make logs and bug reports dramatically easier to read.
Use them from day one.

---

## Endpoint Definition Template

For each endpoint, define all of the following before implementation:

```markdown
### [METHOD] /v1/[resource-path]

**Purpose:** [One sentence — what this endpoint does]
**Auth:** [Required / Optional / None] — [scope or role required, if any]
**Idempotent:** [Yes / No]

#### Request

Path params:
- `:resourceId` — string, required

Query params:
- `cursor` — string, optional (pagination)
- `limit` — integer, optional, default 20, max 100

Body (JSON):
```json
{
  "field": "string, required",
  "optionalField": "string | null, optional"
}
```

#### Response — 200 OK
```json
{
  "ok": true,
  "data": {
    "id": "res_abc123",
    "field": "value",
    "createdAt": "2026-03-16T14:00:00Z"
  },
  "meta": { "requestId": "req_abc123", "timestamp": "..." }
}
```

#### Error Cases
| Scenario | Code | HTTP |
|---|---|---|
| Missing required field | `VALIDATION_ERROR` | 400 |
| Resource not found | `NOT_FOUND` | 404 |
| Not authorized | `FORBIDDEN` | 403 |
```

---

## Auth Surface in Contracts

Auth strategy is set by `adr`. These are the contract-level conventions:

- The auth token travels only in the `Authorization: Bearer <token>` header
- Endpoints must declare their auth requirement explicitly in their definition (Required /
  Optional / None)
- 401 = no valid credentials present; 403 = credentials valid but insufficient permission
  (never conflate these)
- If an endpoint has scope requirements, document them: `Auth: Required — scope: workouts:write`
- One shape per endpoint for every caller; signal permission with 403

---

## Mobile-Specific Considerations (React Native / Expo)

- **Timestamps:** Serialize every timestamp as ISO 8601 UTC (`"2026-03-16T14:00:00Z"`). Epoch
  integers are harder to debug and don't survive serialization in some RN environments.
- **Nulls:** Return explicit `null`, never omit optional fields. Missing keys and null values
  behave differently in JS and RN serializers.
- **Large payloads:** Flag any response likely to exceed ~50KB for a list endpoint. Mobile
  clients on poor connections need pagination or field filtering.
- **Idempotency keys:** For any mutation that could be retried on network failure (POST, PATCH),
  accept an `Idempotency-Key` request header and document it.
- **Offline recovery:** If the client may queue operations while offline, the API must handle
  out-of-order or delayed requests gracefully — document this requirement per endpoint.

---

## Versioning Strategy

- Always prefix with `/v1/` from day one
- Version at the route level, not the header — headers are invisible to logs, proxies, and devs
- Breaking changes require a new version: removing fields, changing field types, changing
  required/optional semantics, changing error codes clients are known to branch on
- Non-breaking additions (new optional fields, new error codes not branched on) do not require
  a new version
- Deprecate before removing: add an RFC 8594 `Sunset` response header carrying the removal date
  before removing any field or endpoint

---

## Output Format

When producing an API contract, output:

1. **Endpoint definitions** — one per section, using the template above
2. **Error code additions** — any project-specific codes this feature introduces
3. **Open questions** — decisions deferred or assumptions made that need confirmation

**Completion criterion:** every endpoint has at least one non-2xx row in Error Cases; every code
used appears in the registry table; every list endpoint declares `limit` default and cap.

If the contract introduces a new resource type or changes an existing one materially, write an
ADR via the `adr` skill to capture the design rationale before implementation begins.

When reviewing an existing API rather than designing a new one: if it already satisfies the
envelope, registry, pagination, auth, and versioning rules above, say so — *"contract is
consistent as written; no changes recommended"* — instead of inventing findings.

Output as a `.md` file: `docs/api/[feature-name]-contract.md`
