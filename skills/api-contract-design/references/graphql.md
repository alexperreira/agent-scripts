# GraphQL Contract Conventions

Read this when the contract being designed or reviewed is GraphQL rather than REST. The error-code
registry in SKILL.md is still canonical — this file maps it onto GraphQL's transport.

---

## Schema Conventions

| Element | Convention | Example |
|---|---|---|
| Types | `PascalCase`, singular | `WorkoutSession` |
| Fields | `camelCase` | `createdAt`, `userId` |
| Enums | `SCREAMING_SNAKE_CASE` members | `enum Status { ACTIVE, ARCHIVED }` |
| Mutations | `verbNoun`, one input object arg | `createWorkoutSession(input: CreateWorkoutSessionInput!)` |
| Mutation payloads | Dedicated `...Payload` type, never a naked entity | `CreateWorkoutSessionPayload` |
| IDs | Opaque prefixed strings via `ID!` | `"sess_abc123"` |

Rules:

- **Nullability is the contract.** Mark a field `!` only when the server can always produce it.
  A nullable field that is never null is a missed guarantee; a non-null field that can fail
  nulls out its whole parent object.
- **One input object per mutation.** Positional scalar arguments break on every addition.
- **Every mutation payload carries a `userErrors: [UserError!]!` list**, so expected failures
  (validation, conflict, permission) travel in `data`, not in the transport-level `errors` array.
- **No REST envelope.** GraphQL's own `data` / `errors` envelope replaces `{ ok, data, meta }`.
  Put request tracing in a `requestId` extension, not in a hand-rolled `meta` field.
- **Timestamps** serialize as ISO 8601 UTC strings (`"2026-03-16T14:00:00Z"`), same as REST.

```graphql
type UserError {
  code: String!      # from the SKILL.md error-code registry
  message: String!   # fixed, human-authored per code
  field: String      # dotted path into the input, when field-scoped
}
```

---

## Resolver Error Mapping

Reuse the error-code registry from SKILL.md — the same `code` strings, routed differently:

| Situation | Where it goes | `code` | HTTP |
|---|---|---|---|
| Field validation failure | `payload.userErrors[]` | `VALIDATION_ERROR` | 200 |
| Resource missing | `payload.userErrors[]` (or `null` field) | `NOT_FOUND` | 200 |
| State conflict / stale write | `payload.userErrors[]` | `CONFLICT` | 200 |
| Authenticated but not permitted | `payload.userErrors[]` | `FORBIDDEN` | 200 |
| No or invalid credentials | top-level `errors[]` | `UNAUTHORIZED` | 401 |
| Query rejected before execution (malformed, depth/complexity cap) | top-level `errors[]` | `VALIDATION_ERROR` | 400 |
| Rate limit hit | top-level `errors[]`, with `Retry-After` | `RATE_LIMITED` | 429 |
| Unhandled resolver exception | top-level `errors[]` | `INTERNAL_ERROR` | 200 |

- Expected, actionable failures belong in `userErrors` so partial data still resolves.
- Put the registry code in `extensions.code` on every top-level error.
- **Never** let a resolver stack trace reach the client. Disable stack traces in the production
  error formatter and log the trace server-side against the `requestId`.
- `message` is a fixed, human-authored string chosen per error code — never the raw exception
  message.

---

## Connection-Style Pagination

Every list field is a Relay-style connection — cursor-based, matching the REST rule that offset
pagination breaks under concurrent writes.

```graphql
type Query {
  workoutSessions(first: Int = 20, after: String): WorkoutSessionConnection!
}

type WorkoutSessionConnection {
  edges: [WorkoutSessionEdge!]!
  pageInfo: PageInfo!
  totalCount: Int          # nullable — omit unless cheap; never COUNT(*) just for this
}

type WorkoutSessionEdge {
  node: WorkoutSession!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

- `first` defaults to 20 and is capped server-side at 100 — the same default and cap as the REST
  `limit` param. Requesting above the cap is a `VALIDATION_ERROR`.
- Cursors are opaque base64 strings; clients must not construct or parse them, and they must not
  encode raw DB IDs.
- Declare the default and cap in the schema description for every connection field.
- Enforce a query depth and complexity limit — an unbounded nested connection query is the
  GraphQL equivalent of an unpaginated list endpoint.
