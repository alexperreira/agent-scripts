# Feature: Polish Pass — script hardening, skill defects, friction

**Goal:** Clear the low-risk debt across scripts and skills in one branch —
dedup shared shell logic, fix wording/config rough edges, repair two skill
defects, and cut permission-prompt friction for this repo.

**Depends on:** none (first slice of a larger improvement program; see
"Program context" below).

## Program context

This is slice 1 of 3 agreed during brainstorming:

1. **Polish pass** (this doc) — low-risk hygiene.
2. `finish-session` flagship — a script+skill that closes out a session
   (PR → merge → branch cleanup), symmetric with `agent-session`.
3. Skill coverage — testing / debugging / SDK-upgrade / env / WSL2-bootstrap
   knowledge skills, selectively.

Two candidate items were **cut as YAGNI** and are intentionally out of scope:

- **B5** — relaxing `require_arg_value`'s rejection of `--`-prefixed values.
  The guard is intentional (catches `--topic --push` missing-value bugs) and no
  script accepts a `--`-prefixed value, so relaxing it would weaken a working
  safety check for a case that cannot occur.
- **D3** — trimming the near-duplicate cross-router paragraphs in the 4 RN
  skill descriptions. Descriptions are the model's trigger-matching surface;
  editing them risks mis-triggering for near-zero payoff.

## Scope

Three logical commits, one branch, one PR.

### Commit 1 — script hardening (B1, B2, B3)

**B1 — shared `run()` helper.** Add the plain dry-run wrapper to
`scripts/lib/common.sh`:

```bash
run() {  # honors global DRY_RUN (default false)
  if [[ "${DRY_RUN:-false}" == true ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}
```

- `scripts/sync-projects` — delete its local `run()` (lines ~71-78) and rely on
  the shared one via `common.sh`. Standardize its `DRY_RUN="false"` init to the
  `DRY_RUN=false` bareword the helper compares against (`== true`).
- `scripts/setup-claude-mcps` — its `run()` (lines ~55-64) has MCP-specific
  fallback behavior (the "skipped … re-run with --replace" branch). That is
  domain logic, **not** boilerplate. Rename it `run_mcp()` and update its call
  sites, so it is clearly distinct from the shared `run()`. Do **not** fold its
  error handling into the shared helper.

**B2 — error-wording consistency.** `scripts/setup-claude-mcps:51`
`die "unknown option: $1"` → `die "unknown argument: $1"` so all six scripts
speak the same dialect. Update the assertion at `scripts/check:83`
(`expect_fail_contains "unknown option: --nope" …`) to expect
`"unknown argument: --nope"`.

**B3 — env-configurable identity in `new-project`.** Replace the three
hardcoded defaults (lines ~166, ~170, ~171) with env-overridable ones,
precedence **CLI flag > env var > default**:

```bash
GITHUB_OWNER="${AGENT_SCRIPTS_OWNER:-alexperreira}"
AUTHOR="${AGENT_SCRIPTS_AUTHOR:-Alex Perreira}"
WEBSITE="${AGENT_SCRIPTS_WEBSITE:-alexhacks.net}"
```

The existing `--owner` flag still wins (it assigns `GITHUB_OWNER` after these
defaults). Document the three env vars in the script `--help` and in
`README.md` / `docs/project-generator.md`. Current behavior with no env set is
unchanged.

### Commit 2 — skill defects (D1, D2)

**D1 — orphaned `permissions.md`.** `skills/rn-platform-gotchas/references/permissions.md`
exists but is never linked, and its content duplicates the inline "Permissions"
section of the SKILL.md body. Adopt the progressive-disclosure pattern the other
three knowledge skills already use: trim the body Permissions section to a short
summary and add an explicit `→ read references/permissions.md for the full
matrix` pointer. Keep the file; remove the duplicated detail from the body.

**D2 — dangling testing-companion promise.** `skills/expo-project-scaffold/SKILL.md`
tells the model to point users to a testing companion skill that does not exist
(testing is a later slice). Soften the wording so it no longer promises a
missing skill. When the testing skill is built (program slice 3), re-add the
pointer.

### Commit 3 — friction (C1)

**C1 — permission allowlist (project scope).** Reduce permission prompts when
working in this repo by adding a read-only Bash/MCP allowlist to
`agent-scripts/.claude/settings.json`. Derive the list from real transcripts via
the `/fewer-permission-prompts` skill rather than hand-guessing. **Project
scope only** — a machine-wide `~/.claude/settings.json` version is a separate
follow-up, out of scope here.

## Verification

- Extend `scripts/check` with a small assertion that the shared `run()` from
  `common.sh` prints a `[dry-run] …` line when `DRY_RUN=true`.
- Existing `check` coverage already exercises B2 (arg-guard wording assertion)
  and B3 (`new-project --dry-run` smoke test with default owner).
- `scripts/check --require-shellcheck` must stay green (this is what CI runs).
- Sanity-run `sync-projects --dry-run` and `setup-claude-mcps --dry-run` to
  confirm the `run()`/`run_mcp()` split still dry-run-prints correctly.

## Steps

- [ ] Commit 1: add `run()` to `common.sh`; refactor `sync-projects` to use it;
      rename `setup-claude-mcps` `run()` → `run_mcp()` (sequential — touches
      shared `common.sh`)
- [ ] Commit 1: B2 wording fix in `setup-claude-mcps` + `check:83` assertion
- [ ] Commit 1: B3 env-configurable defaults in `new-project` + docs
- [ ] Commit 2: D1 trim body + link `permissions.md` in `rn-platform-gotchas`
      (parallel-safe — isolated skill file)
- [ ] Commit 2: D2 soften testing promise in `expo-project-scaffold`
      (parallel-safe — isolated skill file)
- [ ] Commit 3: C1 project-scoped allowlist via `/fewer-permission-prompts`
- [ ] Add `run()` dry-run assertion to `scripts/check`; run
      `scripts/check --require-shellcheck` green
- [ ] Open PR; move this doc to `docs/archive/` on completion

## Parallel-safe notes

- Commit 1 items are **sequential** among themselves (they share
  `common.sh` / cross-script wording assertions).
- Commit 2 items (D1, D2) touch independent skill files and are
  **parallel-safe** with each other and with Commit 1.
- Commit 3 (C1) touches `.claude/settings.json` only — parallel-safe.

## Outputs

- `scripts/lib/common.sh` (new `run()` helper)
- `scripts/sync-projects`, `scripts/setup-claude-mcps`, `scripts/new-project`
- `scripts/check` (new assertion + updated wording assertion)
- `skills/rn-platform-gotchas/SKILL.md`
- `skills/expo-project-scaffold/SKILL.md`
- `.claude/settings.json`
- `README.md`, `docs/project-generator.md` (B3 env-var docs)
