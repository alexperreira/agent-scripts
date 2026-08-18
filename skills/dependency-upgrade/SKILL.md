---
name: dependency-upgrade
description: >
  Audits major version bumps in npm, pip, or other package ecosystems for breaking changes,
  migration paths, and risk surface — then produces a prioritized upgrade plan. Use this skill
  whenever Alex asks to "upgrade dependencies", "bump to the latest version", "update packages",
  "migrate to [library] v[N]", "what breaks if I upgrade X", "is it safe to upgrade", or shares
  a `package.json` / `requirements.txt` and asks what needs attention. Also trigger proactively
  when a task doc introduces a major version bump, when security advisories are mentioned, when
  a library is flagged as outdated or deprecated, or when a new project is being scaffolded and
  dependency choices are being made. Covers breaking change analysis, migration path research,
  blast-radius classification, sequencing, and rollback strategy.
---

# Dependency Upgrade Planning

Audits major version bumps for breaking changes, produces migration plans, classifies upgrades by
blast radius, and sequences them to minimize risk.

**This skill owns the blast-radius scale** (leaf / broad / framework / critical). A task doc
(`task-doc-generator`) carries that label verbatim in its **Risk** row rather than translating it
into Low/Medium/High. Migration tiers are a separate vocabulary owned by `db-migration-safety`.

---

## Core Principles

1. **Major versions are trust boundaries.** A `^1.x` → `2.0` bump is not a patch — it is a
   contract change. Treat every major version bump as a separate migration with its own plan,
   not a line in a batch upgrade PR.

2. **Research before writing code.** Before touching `package.json`, read the migration guide
   and changelog. The answer to "what breaks" should come from documentation, not from running
   the tests and seeing what explodes.

3. **Sequence by blast radius.** Classify each package with the table below and upgrade in
   ascending order.

4. **Rollback must be pre-planned.** Every upgrade plan includes the rollback: what to revert,
   whether a lockfile restore is sufficient, whether any DB migrations or data changes are
   irreversible.

5. **Peer dependencies cascade.** Major bumps often force upgrades to adjacent packages. Map the
   full dependency graph for framework- and critical-blast-radius packages before starting.

---

## One Major Bump Per PR

Each major version upgrade ships in its own PR. If one causes a regression, the isolation is what
makes the rollback cheap.

---

## Blast Radius

Classify each upgrade before planning its sequence:

| Blast radius | Criteria | Examples |
|---|---|---|
| **🟢 leaf** | Leaf utility, no public API surface, easily swappable | `date-fns`, `lodash`, `chalk` |
| **🟡 broad** | Used in multiple files, has migration notes, no framework-level hooks | `axios`, `zod`, `uuid` |
| **🔴 framework** | Framework-level, touches routing / auth / rendering / DB ORM | `react`, `next`, `prisma`, `expo`, `fastapi` |
| **🚨 critical** | Auth, security, or data layer — upgrade errors can corrupt or expose data | `jsonwebtoken`, `bcrypt`, `sqlalchemy` |

---

## Reference Files

| Read when | File |
|---|---|
| Working the per-ecosystem checklist (npm/Node, pip/Python, Expo/React Native) | `references/ecosystems.md` |
| The package is an ORM, auth lib, validation lib, bundler, or styling lib | `references/high-risk-patterns.md` |

---

## Analysis Protocol

For each package being upgraded, work through these steps:

### Step 1 — Identify the delta

```
Current version: X.Y.Z
Target version: A.B.C
Delta type: [patch / minor / major]
Versions skipped: [list any major versions between current and target]
```

One plan section per major-version gap. A v1 → v4 upgrade is three sections, not one.

### Step 2 — Read the migration guide

For every major version bump, find and summarize:
- Official migration guide URL
- Breaking changes list (API removals, renames, behavior changes)
- New required peer dependencies
- Deprecated APIs that were removed in this version
- Node/Python/platform version requirements

**Completion criterion:** every entry in the guide's breaking-changes list is mapped to either a
cited call site (`file:line`) in this codebase or an explicit "not used here". An unmapped entry
blocks the plan.

### Step 3 — Audit usage in the codebase

`grep` for each removed or renamed symbol from Step 2. The **Files affected** list cites
`file:line` per hit and the grep pattern used. Cover:
- Import paths that changed
- API methods that were removed or renamed
- Config file format changes
- Type signature changes (for TypeScript / typed Python)

### Step 4 — Assess migration complexity

| Dimension | Low | Medium | High |
|---|---|---|---|
| **Files affected** | < 5 | 5–20 | > 20 |
| **API changes** | None / additive | Some renames | Fundamental redesign |
| **Behavior changes** | None | Edge cases | Core behavior |
| **New required config** | None | Simple | Complex setup |
| **Peer dep chain changes** | None | 1–2 deps | 3+ deps |

### Step 5 — Plan the migration

Per package:
1. Exact version to pin in `package.json` / `requirements.txt`
2. Files to change (list them)
3. Codemods available (e.g., `next-codemod`, `react-codemod`) — use them before manual edits
4. Manual steps required after codemods
5. Tests to run / smoke-test checklist
6. Rollback: what to revert if this fails (lockfile, specific file changes, config)

---

## Output: Upgrade Plan Document

````markdown
# Dependency Upgrade Plan

_Date: [Month YYYY] | Stack: [e.g., Next.js 14, Node 20, TypeScript 5]_

---

## Scope

| Package | Current | Target | Delta | Blast radius | Skip versions? |
|---|---|---|---|---|---|
| [package-name] | [X.Y.Z] | [A.B.C] | Major | 🔴 framework | [Yes/No] |
| [package-name] | [X.Y.Z] | [A.B.C] | Minor | 🟡 broad | No |

---

## Recommended Sequence

Ordered by blast radius (leaf → critical), with dependencies before dependents.

1. **🟢 leaf** — one PR per package
2. **🟡 broad** — individual PRs, test gate between each
3. **🔴 framework** — individual PRs, feature flag if applicable, staged rollout
4. **🚨 critical** — security review, extra test coverage, rollback runbook required

---

## Package-by-Package Analysis

### [package-name]: vX → vA (🔴 framework)

**Migration guide:** [URL — required for framework/critical packages]

**Breaking changes:**
- [Breaking change 1 — API removed/renamed, behavior changed, etc.] → `src/path/file.ts:88`
- [Breaking change 2] → not used here

**Peer dependency changes:**
- [Required peer dep bump, if any]

**Codemod available:** [Yes — `npx package-codemod` / No]

**Files affected in this codebase:**
- `src/path/to/file.ts:88` — [what needs to change] (grep: `oldSymbolName`)
- `src/another/file.ts:12` — [what needs to change] (grep: `oldSymbolName`)

**Migration steps:**
1. [First step — run codemod, update config, etc.]
2. [Second step]
3. Run: `[specific test command]`

**Rollback:** Revert `package.json` and `package-lock.json` to prior state. No irreversible
changes. [Note if any migration scripts are non-reversible.]

**Estimated effort:** [1–2h / half day / 1–2 days]

---

## Risk Summary

| Risk | Mitigation |
|---|---|
| [Specific regression risk] | [Test coverage, feature flag, staged rollout] |
| [Peer dep conflict] | [Resolve before starting high-risk upgrades] |
| [Missing type definitions] | [Pin `@types/X` separately or use community types] |

---

## Rollback Strategy

If an upgrade fails in production:
1. Roll back with `git revert [PR SHA]`
2. Restore lockfile: `git checkout main -- package-lock.json && npm ci`
3. [Note any steps that are NOT automatically reverted by a git revert]

---

_Archive this plan to: `docs/migrations/YYYY-MM-DD-dep-upgrade.md` after completion._
````

---

## Output Instructions

- Default output: an upgrade plan `.md` file (structure above)
- Filename: `YYYY-MM-DD-dep-upgrade-[scope].md` (e.g., `2026-03-16-dep-upgrade-auth-stack.md`)
- If input is a `package.json` or `requirements.txt`, parse it and identify all packages with
  available major version bumps before drafting the plan
- Cite the migration-guide URL you read for each framework/critical package. An uncited
  breaking-change list is incomplete.
- **No-findings exit:** if every dependency is current, or the only available bumps are patch/minor
  with no breaking-change entries, say so — *"No major bumps pending; nothing to plan."* Don't
  manufacture an upgrade plan.
