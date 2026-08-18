# Skill library audit

Applying the `writing-for-agents` review checklist to Alex's 26 custom skills.

**Coverage:** the cross-library pointer analysis (step 1) covers all 26. The deep body audit
(steps 2–7) covers 17 — the security cluster (8) and the workflow cluster (9). The mobile cluster
(4 Expo/RN skills, 2,054 lines) and the WOD cluster (4 skills, 1,073 lines) were **not** body-audited.
That's a deliberate cap for a first pass, not a clean bill of health.

---

## Part 1 — Cross-library pointer analysis

This is the check no per-file review can perform: descriptions only collide when you read all of
them at once.

### 1.1 Hard collision: `task-doc-generator` vs `wod-task-doc-generator`

These two descriptions share **four identical quoted trigger phrases**:

| Phrase | In |
|---|---|
| `"write a task doc"` | both |
| `"spec this out"` | both |
| `"create a task for CC"` | both |
| `"task doc"` | both |

Side by side, the sentences are near-copies:

> **task-doc-generator:** *Use this skill whenever Alex asks to "write a task doc", "spec this out",
> "create a task for CC", "formalize this"…*

> **wod-task-doc-generator:** *Use this skill whenever Alex asks to "write a task doc", "spec this
> out", "create a task for CC", "formalize this fix"…*

The only discriminator is `for the WODGenerator project`, buried in the first clause of the WOD
description. On every "write a task doc" outside a WOD context, the model is choosing between two
skills whose triggers are the same string — that's a coin flip, and a wrong flip produces a task
doc in the wrong house format.

**Fix.** Make the WOD skill's trigger conditional on the project, not the phrase:

```
Use this skill ONLY when the working directory is the WODGenerator project, or Alex names
WODGenerator explicitly. For task docs in any other project, use `task-doc-generator`.
Trigger phrases are identical to that skill; the project is the discriminator.
```

And add the reciprocal line to `task-doc-generator`. This is exactly the routing the four mobile
skills already do correctly (see 1.3) — the pattern exists in the library, it just wasn't applied here.

### 1.2 Always-loaded cost

26 descriptions, ~18,900 characters ≈ **4,700 tokens loaded on every turn of every session**,
before any skill fires.

Mean description: 727 characters. That's not obviously wrong — your descriptions are deliberately
pushy, which fixes the more common undertriggering failure. But the four longest are all in the
mobile cluster (982–1,015 chars each, ~4,000 chars combined) and they overlap heavily with each
other. That cluster is the place to look if you ever want the number down.

Not a finding to act on yet. A number to know.

### 1.3 The mobile cluster is the pattern to copy

`rn-component-patterns`, `rn-platform-gotchas`, `expo-project-scaffold`, and `expo-build-deploy`
share 18–27 salient terms per pair — by far the highest overlap in the library. They don't collide
anyway, because each description ends with explicit routing:

> *If the question is about project setup or scaffolding, use `expo-project-scaffold` instead. If
> it's about build/deploy, use `expo-build-deploy`. If it's about iOS/Android platform differences,
> use `rn-platform-gotchas`.*

That's the right answer to overlapping domains, and it's already in your library. Nothing else
uses it.

---

## Part 2 — Security cluster (8 skills, 1,390 lines)

### 2.1 Four rules restated across three files each, with no owner declared

| Meaning | Stated in | Should own | Others say |
|---|---|---|---|
| User enumeration (`user not found` vs `wrong password`) | `auth-authorization-audit:69`, `rate-limiting:129-142`, `secure-error-handling:157-160,204` | **auth-authorization-audit** | one checklist line + pointer |
| Error envelope `{ok,error:{code,message},meta}` | `secure-error-handling:110-118,134-142`, `rate-limiting:95-102` | **api-contract-design** (already defines it at `:115`) | delete the JSON, keep headers |
| Payload / body size caps | `rate-limiting:26,50,149-156,173`, `webhook-security:193`, `input-validation:86-92,179`, `threat-modeling:60,78,112` | **rate-limiting-abuse-prevention** | pointer |
| IDOR / ownership-scoped query | `auth-authorization-audit:76-96`, `threat-modeling:59,61,95-99` | **auth-authorization-audit** | STRIDE table cell only |

`webhook-security:193` already does this correctly — *"Payload size capped (see rate-limiting skill)"*.
That's the model. Deleting the duplicates saves ~40 lines and removes three-way drift risk.

### 2.2 Not one of the eight uses `references/` — four have obvious branch material

The convention exists elsewhere in your library (`expo-build-deploy/references/`,
`rn-platform-gotchas/references/`). Every invocation currently pays for content one invocation in
five needs:

- `secure-error-handling:56-143` — 88 lines (43% of the file) of Express-specific `AppError` +
  `errorHandler` → `references/express-error-handler.md`
- `webhook-security:46-92` — 47 lines of Stripe and GitHub provider code → `references/providers.md`
  (the generic HMAC pattern at `:98-112` is what every invocation needs)
- `threat-modeling:85-119` — five mutually exclusive feature-type catalogs → `references/feature-threat-catalog.md`
- `input-validation:120-168` — SQL/path/command injection examples, all saturated pretraining →
  `references/injection-examples.md`, or delete

### 2.3 Negation-by-list is the house style, and it's the most expensive one

Worst instance, `secure-error-handling:33-41`:

> **Never expose these in API responses:** Stack traces / File system paths / Database error
> strings / Library names and versions / Internal service names or URLs / User PII / Environment
> variable names

Nine lines naming seven forbidden things — every one of which is now *in context*. The positive
form is one line and strictly more testable:

> The client-facing error body contains exactly `code`, `message`, optional `details` (validation
> only), and `meta.requestId`. Nothing else ships.

An allowlist of 4 beats a blocklist of 7 — which is what `input-validation:31` ("Allowlist, not
blocklist") tells the *reader* to do. The cluster doesn't follow its own rule. Same pattern at
`secure-error-handling:188-192`, `secrets-env-management:44-53`, `auth:66`, `dependency:104-118`.

### 2.4 ~120 lines cluster-wide the model already knows

`auth:22-27` (AuthN vs AuthZ definitions), `dependency:39-41` ("Don't write your own crypto"),
`dependency:70-88` (`npm audit` invocations), `input-validation:125-138` (SQL interpolation is bad),
`secrets:45-52` (API keys are secrets). None change behavior versus default — and each is
displacing content like `auth:144-153`, which is genuinely non-obvious and sits last.

### 2.5 Four files bury their sharpest instruction below their most generic one

- `secrets-env-management:113-114` — *"If a secret is found in git history — rotate it immediately…
  Assume it's already compromised"* — the highest-stakes, most time-critical line in the file, at
  line 113, inside a section about configuring Gitleaks in CI. Promote to a top-level
  `## If a secret has leaked` block with an ordering gate: **rotate first, scrub second.**
- `dependency-supply-chain-security:104-118` — "Red Flags" (typosquatting, recently transferred
  ownership, minified-only source, postinstall phoning home) is the only non-pretraining content
  in the file, behind 30 lines of `npm audit` boilerplate.
- `threat-modeling:169` — the tie-break rule ("when in doubt, rate higher") appears *after* the
  output format the agent has already filled in.
- `auth-authorization-audit:144-153` — "Common Failure Patterns" (auth middleware excluded for new
  routes, admin check by email domain, GraphQL auth on resolver but not nested fields, soft-deleted
  records not excluded from auth scope) is the only content here the model wouldn't produce
  unprompted, and it's dead last.

### 2.6 Correctness bugs found in passing

Not document-quality issues — actual defects:

- **`webhook-security:82`** — `timingSafeEqual(Buffer.from(expected), Buffer.from(signature))`
  throws `RangeError` on length mismatch. An attacker sending `X-Hub-Signature-256: x` produces an
  uncaught throw → 500. The generic pattern 26 lines later at `:106-110` wraps exactly this in
  try/catch with the comment *"mismatched lengths throw — treat as invalid"*. Two examples in one
  file, one right and one wrong.
- **`rate-limiting:71-82`** — sliding window is three non-atomic Redis round trips
  (`zremrangebyscore` → `zcard` → `zadd`). Under concurrency, N clients all observe `count < limit`
  and all pass — the limit fails at exactly the moment it matters (a burst). Needs a Lua script or
  `MULTI`.
- **`dependency-supply-chain-security:147`** — *"No packages installed with `--ignore-scripts`
  bypass as a workaround"* — `--ignore-scripts` is a *hardening* flag, and the same file flags
  postinstall scripts as a red flag at `:66` and `:111-112`. The checklist item contradicts the
  file's own Red Flags section.
- **`auth-authorization-audit:70`** — `autocomplete="new-password"` does not "prevent credential
  stuffing hints"; credential stuffing is server-side replay of breached credentials. The attribute
  stops the browser autofilling the current password into a change-password field.

### 2.7 Per-file verdicts

| Skill | Verdict | Lines → target |
|---|---|---|
| `input-validation-sanitization` | bloated | 185 → 115 |
| `secure-error-handling` | bloated | 207 → 110 |
| `rate-limiting-abuse-prevention` | bloated | 173 → 105 |
| `dependency-supply-chain-security` | bloated | 149 → 95 |
| `threat-modeling` | acceptable | 170 → 105 |
| `auth-authorization-audit` | acceptable | 153 → 110 |
| `secrets-env-management` | acceptable | 159 → 100 |
| `webhook-security` | acceptable | 194 → 115 |

---

## Part 3 — Workflow cluster (9 skills, 2,223 lines)

### 3.1 The chain is a chain in name only

**Exactly one cross-skill pointer exists in 2,223 lines** — `performance-profiling-protocol:164`
(*"see db-migration-safety skill"*).

Four skills say *"trigger proactively when a task doc…"* — `test-strategy-planner:8`,
`db-migration-safety:9`, `dependency-upgrade:9`, `api-contract-design:8` — and
`task-doc-generator` **never names a single one of them.** Every handoff is declared from the
receiving side and invisible to the sender.

Its "Common Footgun Callouts" (`:192-222`) is exactly where those pointers belong, and instead
restates the downstream skills badly: `:201` says *"Any schema change needs a migration"* where it
should say *"Any schema change: run `db-migration-safety` before writing the migration; put the
assigned tier in the Risk row."*

**Fix:** convert each footgun heading into a dispatch line — `### DB migrations → db-migration-safety`,
`### Package installs → dependency-upgrade`, `### New routes or response shapes → api-contract-design`.

### 3.2 `changelog-generator` cannot consume what `task-doc-generator` emits

`changelog-generator:34-36` makes breaking changes the top-priority output:

> *"Breaking changes get top billing. Any breaking change — API shape, DB schema, env var
> requirement, behavior change — must be surfaced first"*

and `:55` claims to extract from task docs *"Title, scope, affected files, acceptance criteria
completed"*.

But `task-doc-generator`'s Overview table (`:64-72`) has fields `Scope | Risk | Stack | Files
affected | Depends on | Blocks` — **no breaking-change field anywhere in the document.** The
consumer is required to produce a section from data the producer never records, so it infers from
prose or silently omits.

Compounding it: `task-doc-generator:141` archives to `docs/archive/[FILENAME].md`, and
`changelog-generator` never mentions that path. The consumer doesn't know where its input lives.

**Fix.** Add to `task-doc-generator:71`:

```
| **Breaking** | [None / API shape / DB schema / env var / behavior — with the exact migration step] |
```

Change `changelog-generator:55` to: *"Read `docs/archive/*.md` since the last tag; every doc whose
**Breaking** row is not 'None' becomes a Breaking Changes entry verbatim."*

### 3.3 Three mutually incompatible risk scales, none pointing at the others

| Skill | Scale |
|---|---|
| `task-doc-generator:67` | `Low / Medium / High` + one-sentence rationale |
| `dependency-upgrade:56-61` | 🟢 Low / 🟡 Medium / 🔴 High / 🚨 Critical, keyed to blast radius |
| `db-migration-safety:54-93` | 🟢 Tier 1 / 🟡 Tier 2 / 🔴 Tier 3, keyed to lock behavior |

Same emoji vocabulary, three different meanings. A task doc covering a migration has to pick one.

**Fix:** `task-doc-generator` owns the Risk row as a *passthrough* — *"tier from `db-migration-safety`
/ `dependency-upgrade` if applicable, else Low/Medium/High"*. `db-migration-safety` owns migration
tiers. `dependency-upgrade` renames its scale to avoid the collision (`Blast radius: leaf / broad /
framework / critical`).

### 3.4 Two skills orphaned from the chain in both directions

- **`incident-postmortem`** — its Action Items table (`:180-186`) produces *exactly* the input
  `task-doc-generator` exists to consume (`| P0 | [Fix the gap that allowed this to reach
  production] | [Team] | [Date] |`) and never says so. It also never routes systemic decisions to
  `adr` or security fixes to `changelog-generator`'s `### Security` section. **Fix:** append —
  *"Every P0 action item is emitted as a task doc via `task-doc-generator` before this post-mortem
  is marked Final."*
- **`performance-profiling-protocol`** — output format ends at `### Fix Applied` (`:319`) with no
  handoff, despite the fix being a code change needing a task doc and a regression test. **Fix:**
  append — *"Emit the fix as a task doc (`task-doc-generator`) and a regression assertion on the
  baseline metric (`test-strategy-planner`)."*

### 3.5 Duplicated principles with divergent vocabulary

- `task-doc-generator:27` *"**Diagnosis before prescription.**"* vs
  `performance-profiling-protocol:28` *"**Diagnose before prescribing.**"* — same rule, two phrasings.
- Worse: both define a **layer taxonomy** and they don't match. `task-doc-generator:150-160` has
  nine layers (Model/AI output, Prompt, Schema/validation, Service, API/serialization, DB,
  Render/UI, Wiring, Config); `performance-profiling-protocol:316` has five (DB, Application,
  Serialization, Network, Render). **Fix:** `task-doc-generator` owns the layer table; the perf
  skill points at it.
- `"Do not produce .docx"` appears in **four** files (`adr:182`, `task-doc-generator:231`,
  `incident-postmortem:239`, `dependency-upgrade:253`). That's a global preference belonging in
  `CLAUDE.md`, not four skills.

### 3.6 The two most valuable completion-criterion fixes

**`db-migration-safety:256`** — one escape hatch guts a real gate:

> `- [ ] Migration tested against a production-scale data snapshot (or size estimated)`

"Or size estimated" lets the agent skip the work entirely. Sharpen to: *"Row count of every touched
table read from production (state the number and where you read it); estimated runtime derived from
that count. A guessed count fails this check."*

**`performance-profiling-protocol:80`** — *"Add timing instrumentation at each layer boundary"* has
no done-test. Sharpen to: *"The baseline table has one row per layer and the rows sum to within 10%
of the measured end-to-end time. An unexplained gap > 10% means a layer is missing."* That forces
full accounting instead of instrumenting the one layer the agent already suspects.

### 3.7 `performance-profiling-protocol` diagnoses its own problem and ignores it

`:92` says *"Only proceed to the relevant section below once the layer is identified"* — an explicit
admission that everything after Phase 2 is branch material — and then inlines all of it: DB Query
Profiling (`:101-183`, 83 lines), API Latency (`:187-233`, 47), Frontend Render (`:236-283`, 48),
Bundle Size (`:285-303`, 19). A backend query investigation pays for the React re-render table and
the webpack analyzer every single time.

Splitting those four into `references/` takes the file from 343 → ~150 lines. Largest single win in
the library.

### 3.8 `test-strategy-planner` is 63 lines of pretraining

`:52-114` "Test Type Reference" explains what a unit test is (*"A single function, class, or module
in isolation. All dependencies mocked or stubbed"*), what an integration test is, confidence levels
per type. The Coverage Decision Matrix at `:117-135` delivers the same routing in 19 lines and is
the only part carrying project-specific judgment.

**Fix:** delete `:52-114`, keep only the Contract Tests entry (`:105-113`, the non-obvious one) and
fold its trigger into the matrix as a row.

### 3.9 `api-contract-design` promises GraphQL and delivers none

Frontmatter `:4` says *"Designs REST or GraphQL API contracts"*. The body contains zero GraphQL
content — no schema conventions, no resolver error mapping, no connection/pagination pattern. As
written the skill fires on GraphQL work and silently applies REST envelope rules that don't map.

Either add `references/graphql.md` or strike GraphQL from the description.

### 3.10 One thing worth copying everywhere

**`db-migration-safety:273`** — *"If the migration is safe as written, say so clearly — don't
manufacture concerns."*

That's a genuine counterintuitive rule that changes behavior, and it's the only "no findings" exit
in the cluster. `dependency-upgrade` and `performance-profiling-protocol` both lack one and will
manufacture findings without it.

### 3.11 Per-file verdicts

| Skill | Verdict | Lines → target |
|---|---|---|
| `performance-profiling-protocol` | bloated | 343 → 150 |
| `dependency-upgrade` | bloated | 253 → 160 |
| `incident-postmortem` | bloated | 241 → 150 |
| `test-strategy-planner` | bloated | 231 → 120 |
| `api-contract-design` | acceptable | 277 → 210 |
| `db-migration-safety` | acceptable | 273 → 180 |
| `task-doc-generator` | acceptable | 235 → 175 |
| `adr` | acceptable | 185 → 130 |
| `changelog-generator` | acceptable | 185 → 120 |

---

## Part 4 — Suggested order of work

1. **`task-doc-generator` / `wod-task-doc-generator` trigger collision** (1.1) — smallest edit,
   affects every session, currently a coin flip.
2. **`task-doc-generator` `Breaking` row + archive path** (3.2) — unblocks `changelog-generator`,
   which is currently producing its top-priority section from data that doesn't exist.
3. **Footguns → dispatch table in `task-doc-generator`** (3.1) — turns four implied seams into real
   ones with one edit to one file.
4. **The four correctness bugs** (2.6) — these are defects, not doc issues. The `timingSafeEqual`
   one is a live 500.
5. **`performance-profiling-protocol` → `references/`** (3.7) — 343 → 150, largest single win.
6. **Negation sweep on the security cluster** (2.3) — highest volume, most mechanical, safe to batch.
7. Everything else.

Items 1–4 are roughly an hour and carry most of the value.
