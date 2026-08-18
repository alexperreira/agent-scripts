---
name: performance-profiling-protocol
description: >
  Diagnoses slowness systematically: DB query analysis, N+1 patterns, bundle size, render
  bottlenecks, and API latency. Use this skill whenever Alex reports something is "slow",
  "laggy", "taking too long", or asks "why is this slow", "how do I profile this", "what's
  causing the latency", or "how do I optimize this". Also trigger proactively when a feature
  involves large data sets, expensive queries, real-time rendering, or mobile performance
  constraints — before slowness is reported, not after. Covers full-stack profiling: backend
  (Node.js, DB queries), frontend (React/React Native render performance, bundle size), and
  API latency. Always measure before optimizing — an optimization without a baseline is a guess.
---

# Performance Profiling Protocol

A systematic approach to diagnosing and fixing slowness. Covers backend query performance,
N+1 patterns, API latency, frontend render bottlenecks, and mobile-specific constraints.

The cardinal rule: **measure first, optimize second.** Every investigation starts with
instrumentation.

---

## Performance Budgets

Define "fast enough" before profiling. These are the defaults; a project may override a row, but
the override must be stated. **Stop optimizing when the metric is inside its budget.**

| Surface | Budget | Note |
|---|---|---|
| Mobile interaction response | < 100ms | Tap → visible feedback |
| Mobile initial load | < 3s | Cold start → interactive |
| API endpoint | p99 < 500ms | Server-side, excluding client network |
| React render (single commit) | < 16ms | 60fps frame budget |
| DB query | < 10ms | Already fast — caching it is not an optimization |
| Sequential awaits in one handler | < 20ms total | Below this, moving to `Promise.all` is noise |
| Web bundle | Project-defined | Splitting an already-under-budget bundle is not an optimization |

**Optimization gate:** optimize a metric only when a baseline measurement shows it outside this
table. Record the before-number in the Fix Applied section.

---

## Core Principles

1. **One change at a time.** Change one thing, measure again. If you optimize three things
   simultaneously, you don't know what worked.

2. **Establish a baseline first.** You can't know if an optimization helped without a before
   measurement to compare against. Always record baseline metrics before touching code.

3. **Optimize the constraint, not the convenient thing.** If the DB query takes 800ms and the
   serializer takes 2ms, optimizing the serializer is noise. Find the actual bottleneck — it's
   usually the constraint in the critical path.

4. **Document what you measured and changed.** Performance work without recorded baselines and
   measurements is not reproducible. Future you (or Claude) will need this to validate that a
   regression didn't creep back in.

---

## Phase 1: Establish the Baseline

Before touching any code, record:

```markdown
## Performance Baseline: [Feature / Endpoint / Screen]
Date: [when measured]
Environment: [local / staging / production]

| Metric | Value | Tool used |
|---|---|---|
| [e.g. GET /v1/sessions p50 latency] | [e.g. 420ms] | [e.g. server logs / Datadog] |
| [e.g. Time to interactive — Sessions screen] | [e.g. 2.1s] | [e.g. React DevTools Profiler] |
| [e.g. DB query time for sessions list] | [e.g. 380ms] | [e.g. EXPLAIN ANALYZE] |

Reproduction steps:
1. [Exact steps to trigger the slow behavior]
2. [Data set size / conditions at time of measurement]
```

---

## Phase 2: Locate the Bottleneck

Work top-down through the stack. Don't jump to solutions.

### Step 1 — Identify the slow layer

Add timing instrumentation at each layer boundary:

```ts
// API handler timing
const t0 = performance.now();
const result = await service.getSessions(userId);
const t1 = performance.now();
logger.info('getSessions', { durationMs: t1 - t0, userId });
```

**Completion criterion:** the baseline table has one row per layer and the rows sum to within 10%
of the measured end-to-end time. An unexplained gap > 10% means a layer is missing.

Name the layer using the nine-layer **Layer Reference** table in `task-doc-generator` — that table
is the shared vocabulary; do not invent a competing one here.

### Step 2 — Narrow within the layer

**Completion criterion:** the bottleneck statement names a file, query, or component and a measured
number; a layer name alone is rejected. "The DB is slow" fails. "The `sessions` query with a
`userId` filter does a full table scan — no index on `user_id`, 380ms" passes.

Only once the layer is identified, read the matching reference:

| Identified layer | Read this when narrowing |
|---|---|
| DB / persistence | `references/db-queries.md` — `EXPLAIN ANALYZE` node table, index checklist, N+1 fix, slow query log |
| API / serialization (request lifecycle) | `references/api-latency.md` — `Server-Timing` breakdown pattern, common latency sources |
| Render / UI (React, React Native) | `references/frontend-render.md` — Profiler workflow, re-render fixes, Expo/RN constraints |
| Config / build (web bundle) | `references/bundle-size.md` — analyzer commands, common size culprits |

---

## N+1 Check (inline — run this first on any list endpoint)

**Symptom:** query count in logs scales linearly with result set size.

```ts
// Enable query logging in your ORM
// Prisma:
const prisma = new PrismaClient({ log: ['query'] });

// Look for repeated queries with different IDs:
// SELECT * FROM comments WHERE post_id = 1
// SELECT * FROM comments WHERE post_id = 2
// SELECT * FROM comments WHERE post_id = 3  ← N+1
```

Fix and full explanation: `references/db-queries.md`.

---

## Performance Investigation Output Format

```markdown
## Performance Investigation: [Feature / Endpoint / Screen]

### Baseline
[Table of metrics from Phase 1]

### Bottleneck Identified
**Layer:** [name from task-doc-generator's Layer Reference table]
**Root cause:** [One sentence — names a file, query, or component, plus a measured number]
**Evidence:** [What measurement or tool confirmed this]

### Fix Applied
[What was changed — with before/after code if relevant. State the before-number.]

### Result
| Metric | Before | After | Budget | Delta |
|---|---|---|---|---|
| [metric] | [value] | [value] | [from budget table] | [% improvement] |

### Follow-on work (if any)
- [Any secondary bottlenecks deferred, or monitoring to add]
```

---

## No-Findings Exit

If the baseline shows every metric inside the budget table, say so plainly: *"Baseline measured;
all metrics are within budget — no optimization recommended."* That is a complete and correct
result. Don't manufacture a bottleneck to have something to report.

---

## Handoff

Emit the fix as a task doc (`task-doc-generator`) and a regression assertion on the baseline
metric (`test-strategy-planner`).
