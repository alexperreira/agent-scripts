---
name: task-doc-generator
description: >
  Produces structured engineering task documents (.md files) ready to hand off to Claude Code or
  any implementation agent. Use this skill whenever Alex asks to "write a task doc", "spec this
  out", "create a task for CC", "formalize this", "write this up for implementation", or describes
  a bug or feature that needs to be handed off for execution. Also trigger proactively whenever a
  diagnosis or design decision has been reached and the next step is implementation — even if Alex
  doesn't say "task doc". Produces scope tables, pre-code audit gates, out-of-scope callouts,
  acceptance criteria, implementation sketches, and stack-tuned footgun warnings.
---

# Task Document Generator

Produces `.md` task documents suitable for handoff to Claude Code (CC) or any agentic
implementation tool. These docs are the contract between planning and execution.

Quality of the task doc directly determines quality of the implementation. A good task doc
eliminates ambiguity, prevents scope creep, and gives the implementer exactly the right context —
no more, no less.

---

## Core Principles

1. **Diagnosis before prescription.** Never prescribe an implementation until the root cause or
   design intent is confirmed. If the layer or location of a fix is uncertain, write a diagnostic
   step first (Task 0). Do not guess — assign a layer.

2. **Scope is a feature.** Every task doc must have an explicit **Out of Scope** section. Name
   things adjacent to the work that must NOT be touched. Implementation agents over-reach without
   explicit fences.

3. **Files and locations over vague descriptions.** Reference exact file paths, function names,
   and approximate line numbers where known. "Update `parseResponse()` in `src/api/client.ts`
   around line 88" is better than "fix the response parser."

4. **Implementation sketches, not prose.** Provide actual code patterns at every non-trivial task.
   Agents follow examples more reliably than written instructions.

5. **Acceptance criteria are observable.** Every criterion must be verifiable by looking at
   output, a log, or a UI — not "the code is correct."

6. **Name the footguns.** Call out serialization traps, migration risks, type mismatches, and any
   place where an agent is likely to over-reach (new DB migrations, installing packages, auth
   changes, touching unrelated routes).

---

## Document Structure

Every task doc follows this structure. Do not omit sections.

````markdown
# [TASK_NAME].md
_Prepared by: CD | Date: [Month YYYY]_

---

## Overview
[2–4 sentence plain-English summary of what this task does and why it matters]

| Field | Detail |
|---|---|
| **Scope** | [e.g. "API layer only — no DB migrations, no frontend changes"] |
| **Risk** | [Tier from `db-migration-safety` or `dependency-upgrade` if either applies — carry their label verbatim. Otherwise Low / Medium / High with a one-sentence rationale.] |
| **Breaking** | [None / API shape / DB schema / env var / behavior — and if not None, the exact step a consumer must take] |
| **Stack** | [e.g. "Next.js 14, Prisma, PostgreSQL"] |
| **Files affected** | [comma-separated list] |
| **Decisions** | [ADR-NNN if this implements or depends on a recorded decision, else "none"] |
| **Depends on** | [what must exist or be true before this runs] |
| **Blocks** | [what can't start until this is done, if anything] |

> **The `Breaking` row is load-bearing downstream.** `changelog-generator` reads it verbatim to
> build the Breaking Changes section of the release notes, which is the first thing that section
> looks for. "None" is a valid and common answer — but it must be stated, not omitted. An empty
> `Breaking` row means the change silently disappears from the changelog's top-priority section.
>
> **The `Risk` row is a passthrough, not a fourth scale.** Migration tiers belong to
> `db-migration-safety`; upgrade blast radius belongs to `dependency-upgrade`. Carry whichever
> label applies rather than translating it into Low/Medium/High, so one vocabulary survives the
> whole chain.

---

## Context
[Why this change is being made. Link to prior conversation, issue, or decision if relevant.
Include any constraints — performance budget, API contract requirements, backward compatibility
requirements. Omit if context is fully captured in Overview.]

---

## Problem / Goal
[For bugs: what is broken. Concrete symptoms — what the user sees, what a log shows, what a
failing test asserts. Be specific. For features: what must become true that isn't true now.]

---

## Diagnosis
[For bugs: assign the defect to a specific layer. See Layer Reference below. Include evidence.
This section prevents CC from "fixing" the wrong layer.

> **Root cause:** [one sentence — e.g. "API layer: `user.role` is present in the DB record
> but stripped from the response serializer in `formatUser()`."]

For features: describe the design decision made and why. This section captures intent so CC
doesn't have to infer it.

If diagnosis is NOT yet confirmed, include a diagnostic step as Task 0.]

---

## Tasks

### Task [N] — [Short label]

**File:** `[path/to/file]`

[What CC must do — specific, with implementation sketch]

```ts
// Code sketch showing the pattern — actual language used in the project
```

#### Sub-task [NA] — [Label]
[If the task has multiple distinct steps, break them out here]

---

## Out of Scope

- [Explicit item CC must NOT touch]
- [e.g. "No new DB migrations"]
- [e.g. "No changes to auth middleware"]
- [e.g. "No new npm/pip installs without explicit approval"]
- [e.g. "Do not refactor adjacent code unless directly required"]
- [e.g. "Mobile surface not in scope unless called out"]

---

## Acceptance Criteria

- [ ] [Observable outcome — what user sees, what log shows, what test asserts]
- [ ] [Another criterion]
- [ ] [Edge case verified]
- [ ] [Regression: previously working surfaces still work]
- [ ] [If relevant: no new console errors or warnings]

---

_Pass this document directly to CC. All tasks are self-contained and executable sequentially._
_Archive to: docs/archive/[FILENAME].md after completion._
````

---

## Layer Reference

For bugs, assigning the fix to the correct layer is the most important decision in the doc.

| Layer | What lives here | Typical symptoms |
|---|---|---|
| **Model / AI output** | LLM response content, structured output, JSON fields | Field missing from raw output, wrong value, schema mismatch |
| **Prompt / system prompt** | System prompt, few-shot examples, output schema instructions | Model consistently omits or misformats a field despite instructions |
| **Schema / validation** | Zod, Pydantic, JSON Schema, type definitions | Valid data stripped by overly strict validation; wrong enum; missing field in type |
| **Service / business logic** | Domain logic, data transforms, calculations | Correct input, wrong output; off-by-one; edge case not handled |
| **API / serialization** | Route handlers, response formatters, serializers | Field present in DB/service but absent in API response |
| **DB / persistence** | Queries, migrations, ORM models | Data written incorrectly; query returns wrong rows; missing index causing slowness |
| **Render / UI** | Frontend components, templates | Field present in props/payload but not displayed |
| **Wiring / mapping** | Data transforms between layers, prop drilling, adapters | Field present upstream, absent downstream |
| **Config / environment** | Env vars, feature flags, build config | Works locally, fails in prod; wrong API key; feature disabled unexpectedly |

**Diagnostic gate rule:** If the layer is uncertain, confirm it with a log step before writing fix
tasks. Promote this to **Task 0 — Diagnostic** (see template below).

---

## Template: Diagnostic Task (Task 0)

Use when the root cause layer is not yet confirmed.

```markdown
### Task 0 — Diagnostic: Confirm layer

**Goal:** Determine whether [field / behavior] is [broken at layer A] or [broken at layer B]
before writing a fix.

**Steps:**
1. Add a temporary log at [location] immediately after [event]:
   ```ts
   console.log('[DEBUG task-0]', JSON.stringify(targetData, null, 2));
   ```
2. Trigger the behavior. Check the log.
3. Report findings before proceeding:
   - **If [X] → layer A bug. Proceed to Task 1A.**
   - **If [Y] → layer B bug. Proceed to Task 1B.**

Remove the log before committing.
```

---

## Dispatch — run these before writing the task

When the work touches one of these areas, the specialist skill runs **first** and its output goes
into the task doc. Writing the task doc first and reviewing afterwards inverts the order that
matters: a migration tier or a breaking API shape changes what the tasks should say.

| If the work touches | Run | What comes back into the doc |
|---|---|---|
| Any schema change — add, drop, rename, retype, index, constraint, backfill | `db-migration-safety` | The assigned tier goes in the **Risk** row verbatim; the expand/contract sequence becomes the task ordering |
| New or upgraded packages | `dependency-upgrade` (major bumps) or `dependency-supply-chain-security` (new packages) | Blast-radius label in the **Risk** row; the migration steps become tasks |
| New routes, changed response shapes, a new client-server boundary | `api-contract-design` | The envelope and error codes go in the implementation sketch; any shape change sets the **Breaking** row |
| A new endpoint, user role, or data-access pattern | `auth-authorization-audit` | Ownership checks become acceptance criteria |
| What "tested" means for this feature | `test-strategy-planner` | Its Must Test rows become acceptance criteria checkboxes |
| A decision that would be painful to reverse | `adr` | The ADR number goes in the **Decisions** row |

## Common Footgun Callouts

Include relevant ones inline in the task body when applicable.

### Drive-by edits
CC will frequently touch adjacent code "while I'm in here." The Out of Scope section is the
primary defense. State the positive bound: edit only the files named in **Files affected**; adding
a file requires stating why in the task.

### Package installs
When the task should use what's already there: "Use only packages already present in
`package.json` / `requirements.txt`." When it genuinely needs a new one, dispatch above.

### Auth / middleware
If a route handler or middleware is nearby, state that auth logic stays as-is unless the task
names it. If the task does touch auth, dispatch above.

### Environment variables
If a new config value is needed, it must be added to `.env.example` and documented. Secrets reach
the process through the environment or a secrets manager — see `secrets-env-management`.

### Type vs. runtime
For TypeScript/typed languages: distinguish between type-level changes (interface, type alias) and
runtime-level changes (parsing, serialization). CC sometimes fixes one without the other, so name
both explicitly when both are required.

### Idempotency
For scripts, migrations, and data backfills: require idempotent design unless explicitly
unnecessary. State this as a requirement in the task, not the acceptance criteria.
`db-migration-safety` owns the rules for migrations specifically.

---

## Output Instructions

- Filename: `DESCRIPTIVE_SLUG.md` in `SCREAMING_SNAKE_CASE`
- Default output: a `.md` file written to the filesystem (not inline prose)
- Date format: `Month YYYY` (e.g. `March 2026`)
- Do not produce a `.docx` unless explicitly asked
- Keep each Task section independently executable where possible — CC handles one task at a time
- If the task doc exceeds ~4 tasks, consider whether it should be split into multiple docs with
  a dependency order
- Footer must always include the two lines: pass-to-CC note and archive path reminder
