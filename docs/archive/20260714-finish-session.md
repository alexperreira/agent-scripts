# Feature: finish-session — close out an agent session (PR → land → cleanup)

**Goal:** Add a low-privilege `scripts/finish-session` that closes out an agent
work session symmetric to `agent-session`: ensure the branch is pushed, open (or
reuse) a PR, enable merge-when-green, and clean up the branch — plus a wrapping
`finish-session` skill and `scripts/check` coverage.

**Depends on:** none directly, but relies on the branch protection enabled on
2026-07-14 (main requires the `scripts-check` status check) — that is what makes
`gh pr merge --auto` a real gate. Slice 2 of the improvement program (slice 1 =
polish pass, merged in #7).

## Design (settled during brainstorming)

| Decision | Resolution |
|---|---|
| Default scope | **Full land** — enable auto-merge, then (default) **wait** until merged and delete the local branch, so it feels synchronous. `--no-wait` returns right after queuing. |
| Merge strategy | **Squash** default; `--merge` / `--rebase` override. |
| CI gate | `gh pr merge --auto` — merges only when the required `scripts-check` passes. |
| PR text | Auto-derive: title from the branch topic, body from `git log <base>..HEAD`. `--title` / `--body` override. |
| Privilege | **Low.** No force-push. Local branch deleted only with `git branch -d` (refuses unmerged) — never `-D`. No branch-protection/admin API calls. Skill gets `allowed-tools: Bash` only. |

"Full land" is necessarily **asynchronous** with a required check — the merge
happens the moment CI goes green, not the instant the command runs. Default
`--wait` hides that by polling to completion; `--no-wait` exposes it.

## CLI

```
finish-session [options]
  --title TEXT       Override the auto-derived PR title
  --body TEXT        Override the auto-derived PR body
  --base BRANCH      Base branch to merge into (default: main)
  --squash           Squash merge (default)
  --merge            Merge commit instead of squash
  --rebase           Rebase merge instead of squash
  --draft            Open the PR as a draft; do NOT enable auto-merge
  --no-merge         Ensure the PR exists, but do not enable auto-merge
  --no-wait          Enable auto-merge and return; don't block until merged
  --dry-run          Print the git/gh commands without executing them
  --help, -h         Show this help
```

`--squash` / `--merge` / `--rebase` are mutually exclusive (last one wins, or
`die` on conflict — plan's choice; prefer last-wins for simplicity).

## Behavior / flow

1. **Preconditions** (`die` on failure): `require_cmd git`; `require_cmd gh`.
   Current branch must not be the base branch and must not be detached HEAD.
   Working tree must be clean — abort if there are uncommitted changes (we are
   about to land; a partial tree should not be merged). Branch must have at
   least one commit ahead of `<base>`.
2. **Ensure pushed.** If the branch has no upstream or is ahead of its upstream,
   `git push -u origin <branch>` (never `--force`).
3. **Ensure PR.** `gh pr view <branch>` — if none exists, `gh pr create --base
   <base> --head <branch>` with the derived (or overridden) title/body. If
   `--draft`, create with `--draft` and stop (no auto-merge on drafts).
4. **Stop early** if `--no-merge` (PR ensured, nothing more) or `--draft`.
5. **Enable auto-merge.** `gh pr merge <branch> --auto --squash --delete-branch`
   (strategy flag swapped per `--merge`/`--rebase`). `--delete-branch` lets
   GitHub delete the remote branch after the merge completes.
6. **Wait (default) or return.**
   - Default: poll `gh pr view <branch> --json state,mergedAt,mergeStateStatus`
     until `state == MERGED`. If the required check fails (PR becomes blocked
     with failing checks), stop and report — leave the PR open, do NOT delete
     anything. On merge: `git checkout <base>`, `git pull --ff-only`,
     `git branch -d <branch>` (safe delete; remote already gone).
   - `--no-wait`: print the PR URL and that auto-merge is enabled; exit 0.
7. All state-changing commands go through the shared `run()` so `--dry-run`
   prints them instead of executing. Dry-run must be **fully offline**: derive
   the plan from local git only (branch name, `git log <base>..HEAD`), and print
   the intended `gh`/`git` commands without calling `gh`.

## PR text derivation

- **Title:** strip the `agent/<repo>/<YYYYMMDD>-` prefix from the branch name to
  get the topic slug, replace `-` with spaces, capitalize first letter.
  e.g. `agent/agent-scripts/20260714-finish-session` → `Finish session`.
- **Body:** `git log <base>..HEAD --pretty=format:'- %s'` (commit subjects as a
  bullet list). `--body` overrides wholesale.

## Guardrails (low-privilege — explicit)

- Never `git push --force` / `--force-with-lease`.
- Local branch removal is `git branch -d` only (never `-D`); if it refuses
  (unmerged), warn and leave the branch — do not escalate.
- No calls to the branch-protection / rulesets / admin APIs.
- Abort on: base branch checked out, detached HEAD, dirty tree, zero commits
  ahead of base.
- `--dry-run` performs no network calls and no writes.

## Reuse & consistency

- Source `scripts/lib/common.sh`; use `die` / `warn` / `require_cmd` /
  `require_arg_value` / the shared `run()` from slice 1.
- Mirror `agent-session`'s structure: `set -euo pipefail`, `SCRIPT_DIR`
  resolution, a `usage()` heredoc, the same `while/case` arg-parsing style.
- `DRY_RUN=false` default so the shared `run()` executes by default.

## Skill

`skills/finish-session/SKILL.md`, `allowed-tools: Bash`. Description written as a
trigger: fires on "finish this / wrap up the session / open a PR / land this /
merge the branch / clean up the branch", and proactively when work is complete
and pushed. Body: how to invoke, the wait/no-wait nuance, that it relies on the
`scripts-check` branch-protection gate, and that it is the symmetric partner to
`agent-session`. Mirror the existing `agent-session` skill's length/shape.

## Verification (extend `scripts/check`)

- `finish-session --help` is picked up by the existing help smoke loop.
- Add an arg-guard assertion: `finish-session --title` → `missing value for --title`.
- Add an **offline dry-run smoke test**: create a throwaway git repo in a temp
  dir, make a `main` + a feature branch with one commit, run
  `finish-session --dry-run --base main` with `PATH` such that `gh` is stubbed or
  the code path avoids `gh` in dry-run; assert it exits 0 and prints the planned
  `gh pr create` / `gh pr merge` lines. (Mirror the `new-project --dry-run`
  smoke test pattern.)
- `scripts/check --require-shellcheck` must stay green (CI gate).

## Registration / docs

- `bootstrap-home-links` already symlinks `scripts/` and each skill wholesale, so
  `~/scripts/finish-session` and the skill appear with no change there — but
  confirm the skill is picked up (7 → 8 skills validated by `check`).
- Update `README.md` (scripts + skills tables) and add a short
  `docs/finish-session.md` mirroring `docs/agent-session.md`.
- Update `CLAUDE.md` "Standard PR flow" / "Canonical Paths" to point at
  `finish-session` as the close-out counterpart to `agent-session`.

## Steps

- [ ] Write `scripts/finish-session` (preconditions → push → PR → auto-merge →
      wait/cleanup), sourcing `common.sh`
- [ ] Add `skills/finish-session/SKILL.md` (`allowed-tools: Bash`)
- [ ] Extend `scripts/check`: arg-guard + offline dry-run smoke test
- [ ] `docs/finish-session.md` + README tables + CLAUDE.md close-out note
- [ ] Run `scripts/check --require-shellcheck` green; manual `--dry-run` sanity
- [ ] PR via `agent-session` push already done; land it (dogfood: use
      `finish-session` itself if far enough along, else the manual flow)
- [ ] Archive this doc to `docs/archive/` on merge

## Parallel-safe notes

- The script (`scripts/finish-session` + `scripts/check` edits) and the skill
  (`skills/finish-session/SKILL.md`) touch independent files — **parallel-safe**.
- Docs (`README.md`, `docs/finish-session.md`, `CLAUDE.md`) are independent —
  parallel-safe, but should reflect the final CLI, so write them last.

## Outputs

- `scripts/finish-session` (new)
- `skills/finish-session/SKILL.md` (new)
- `scripts/check` (new assertions)
- `docs/finish-session.md` (new), `README.md`, `CLAUDE.md` (updated)
