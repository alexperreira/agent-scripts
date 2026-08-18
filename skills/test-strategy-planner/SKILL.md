---
name: test-strategy-planner
description: >
  Maps test coverage strategy for a feature or system: unit vs. integration vs. e2e, what must
  be tested vs. what can be skipped, tooling recommendations, and where the coverage gaps are.
  Use this skill whenever Alex asks "what should I test here", "how do I test this", "is this
  worth writing a test for", "what's the right test type for this", or is starting a new feature
  and needs a testing plan. Also trigger proactively when a task doc is being written for a
  non-trivial feature — the test strategy should be defined before implementation starts, not
  after. Covers React Native / Expo mobile testing constraints, API integration testing, and
  how to test AI/LLM outputs where determinism is limited.
---

# Test Strategy Planner

Maps coverage strategy for a feature or system — what to test, at what layer, with what tools,
and what's safe to skip.

Testing everything equally is as wrong as testing nothing. The goal is maximum confidence per
unit of test maintenance cost. That means testing the right things at the right layer, not
achieving a coverage number.

---

## Core Principles

1. **The testing pyramid is a cost model.** Unit tests are cheap to write and fast to run.
   E2E tests are expensive to write and slow to run. Push coverage as low in the pyramid as
   it can go without losing confidence.

2. **Not everything needs a test.** Config files, simple getters, generated code, and
   framework boilerplate don't need tests. Testing them adds maintenance burden with no
   confidence gain.

3. **Every test must be able to fail.** Every test must have at least one realistic input that
   would cause it to fail if the code is broken.

4. **Test the contract, not the implementation.** For API handlers: test the response shape
   and status codes. For UI components: test what the user sees and can interact with.
   For services: test the return values and thrown errors.

5. **Regression tests are mandatory for bugs.** Every bug fix must be accompanied by a test
   that would have caught the original bug. If you can't write one, the fix isn't complete.

---

## Contract Tests

The one test type worth defining explicitly, because it isn't standard practice everywhere.

**What:** Verifies that a producer (API) and consumer (client) agree on the shape of data
exchanged, without requiring both to be running simultaneously.

**When to use:**
- Mobile client + backend API where the client can't be updated as fast as the server
- Microservices with independently deployed consumers
- Any API where a shape change would silently break a client

**Confidence level:** High for preventing silent breaking changes across deployment boundaries.

---

## Coverage Decision Matrix

The core of this skill. Use it to decide what type of test to write for a given piece of code:

| Code type | Recommended test type | Skip if... |
|---|---|---|
| Pure function with logic | Unit | Logic is trivial (1-2 lines, no branches) |
| Data transformer / mapper | Unit | Simple field rename with no conditionals |
| Validator / parser | Unit + edge cases | Thin wrapper around a library |
| API route handler | Integration (real DB) | Handler is a thin proxy with no logic |
| Auth middleware | Integration | Already covered by existing auth test suite |
| DB query / repository | Integration | Simple CRUD with no custom logic |
| Response shape consumed by an independently deployed client | Contract | Producer and consumer always ship together |
| React component (display) | Unit (render test) | Purely presentational, no state or interaction |
| React component (interactive) | Unit (user event test) | Interaction is already covered by e2e |
| Critical user journey | E2E | Journey is already covered by integration tests |
| Background job / worker | Integration | Job has no logic — just calls other tested services |
| Config / constants | None | — |
| Generated code | None | — |

---

## Reference Files

| Read when | File |
|---|---|
| Choosing test tooling for a stack (Node/TS, Expo/RN, contract testing) | `references/tooling.md` |
| The feature produces or consumes LLM output | `references/llm-testing.md` |

---

## Test Plan Output Format

When producing a test strategy, structure output as:

```markdown
## Test Strategy: [Feature Name]

### Coverage Completeness
Every public function, endpoint, screen, and state transition introduced by the feature appears
in exactly one of Must Test / Should Test / Skip. An unlisted surface blocks the plan.
[List any surface still unaccounted for here.]

### Must Test (blocking — merge requires these)
| What | Type | Tool | Notes |
|---|---|---|---|
| [e.g. validation rejects invalid email] | Unit | Vitest | Cover null, malformed, too-long |
| [e.g. POST /users returns 201 with correct shape] | Integration | Supertest + real DB | |

### Should Test (high value, can be follow-up)
| What | Type | Tool | Notes |
|---|---|---|---|
| ... | | | |

### Skip (and why)
| What | Reason |
|---|---|
| [e.g. config constants] | No logic to break |
| [e.g. UI layout] | Covered by visual QA; not worth snapshot maintenance |

### Open Questions
- [Any testing decisions that require clarification before writing tests]
```

**Must Test rows become acceptance-criteria checkboxes in the task doc** (`task-doc-generator`).

---

## Red Flags in Existing Test Suites

Call these out when reviewing or inheriting a test suite:

- **Tests that only assert `toBeDefined()`** — passing but not verifying anything meaningful
- **No test DB — mocking the ORM** — integration tests that mock the DB miss query bugs,
  constraint violations, and N+1 patterns entirely
- **Tests coupled to implementation** — tests that break on refactors that don't change behavior
- **Flaky tests left in suite** — a flaky test that's skipped or retried is technical debt that
  erodes confidence in the whole suite
- **100% coverage target** — coverage is a floor, not a ceiling; chasing 100% produces tests
  that exist to hit lines, not to find bugs
- **No e2e for the critical path** — if the auth flow or core feature creation has never been
  tested end-to-end, it's only a matter of time

If the existing suite covers every Must Test row and none of the red flags apply, say so:
*"Coverage is adequate as written — no additions required."*
