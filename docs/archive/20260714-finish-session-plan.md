# finish-session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a low-privilege `scripts/finish-session` (plus a wrapping skill and `check` coverage) that closes out an agent session: ensure the branch is pushed, open/reuse a PR, enable merge-when-green, and clean up.

**Architecture:** A single Bash script sourcing `scripts/lib/common.sh`, built in three layers — (1) arg-parse + preconditions, (2) an offline `--dry-run` planner, (3) the live push→PR→auto-merge→wait→cleanup path. Tests are assertions in `scripts/check` (the repo's harness); the async merge path is verified by dogfooding.

**Tech Stack:** Bash (`set -euo pipefail`), `git`, `gh` CLI, the repo's `scripts/check` smoke harness, shellcheck (CI).

## Global Constraints

- Every script: `#!/usr/bin/env bash`, `set -euo pipefail`, source `scripts/lib/common.sh`, provide `--help`, use `die`/`warn`/`require_cmd`/`require_arg_value`/`run`.
- Unknown-arg error string MUST be exactly `unknown argument: $1` (matches the other five scripts + `check`).
- **Low-privilege, non-negotiable:** never `git push --force`/`--force-with-lease`; local branch removal is `git branch -d` only (never `-D`); no branch-protection/ruleset/admin API calls.
- `--dry-run` performs zero network calls and zero writes; it prints the plan from local git state only.
- Default merge strategy is `squash`; `--merge`/`--rebase` override (last flag wins).
- Base branch defaults to `main`.
- Relies on the branch-protection gate enabled 2026-07-14 (main requires `scripts-check`) for `gh pr merge --auto` to be meaningful.

---

### Task 1: Script skeleton — arg parsing, preconditions, `--help`

**Files:**
- Create: `scripts/finish-session`
- Modify: `scripts/check` (add arg-guard assertion)

**Interfaces:**
- Consumes: `scripts/lib/common.sh` → `die`, `warn`, `require_cmd`, `require_arg_value`, `run`.
- Produces: an executable `scripts/finish-session` with globals `BASE`, `TITLE`, `BODY`, `STRATEGY`, `DRAFT`, `DO_MERGE`, `WAIT`, `DRY_RUN`, `BRANCH` and a working `--help`/arg-guard, aborting on bad preconditions.

- [ ] **Step 1: Write the failing test** — add to `scripts/check` after the existing argument-guard block (after line ~83, the `setup-claude-mcps --nope` assertion):

```bash
expect_fail_contains "missing value for --title" "${SCRIPT_DIR}/finish-session" --title
```

- [ ] **Step 2: Run to verify it fails**

Run: `scripts/check`
Expected: FAIL — `not executable` / discovery error, because `scripts/finish-session` doesn't exist yet.

- [ ] **Step 3: Create `scripts/finish-session`** with skeleton through preconditions:

```bash
#!/usr/bin/env bash
# finish-session — close out an agent session: ensure a PR, land it when CI is
# green, and clean up the branch. Symmetric partner to agent-session.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

BASE="main"
TITLE=""
BODY=""
STRATEGY="squash"   # squash | merge | rebase
DRAFT=false
DO_MERGE=true
WAIT=true
DRY_RUN=false

usage() {
  cat <<'EOF'
finish-session — open/reuse a PR for the current branch, land it when CI is
green, and clean up.

Usage:
  scripts/finish-session [options]

Options:
  --title TEXT       Override the auto-derived PR title
  --body TEXT        Override the auto-derived PR body
  --base BRANCH      Base branch to merge into (default: main)
  --squash           Squash merge (default)
  --merge            Merge commit instead of squash
  --rebase           Rebase merge instead of squash
  --draft            Open the PR as a draft; do not enable auto-merge
  --no-merge         Ensure the PR exists, but do not enable auto-merge
  --no-wait          Enable auto-merge and return; do not block until merged
  --dry-run          Print the git/gh commands without executing them
  --help, -h         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)    require_arg_value "$1" "${2:-}"; TITLE="${2:-}"; shift 2 ;;
    --body)     require_arg_value "$1" "${2:-}"; BODY="${2:-}"; shift 2 ;;
    --base)     require_arg_value "$1" "${2:-}"; BASE="${2:-}"; shift 2 ;;
    --squash)   STRATEGY="squash"; shift ;;
    --merge)    STRATEGY="merge"; shift ;;
    --rebase)   STRATEGY="rebase"; shift ;;
    --draft)    DRAFT=true; shift ;;
    --no-merge) DO_MERGE=false; shift ;;
    --no-wait)  WAIT=false; shift ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --help|-h)  usage; exit 0 ;;
    *)          die "unknown argument: $1" ;;
  esac
done

require_cmd git
require_cmd gh

# ── Preconditions ────────────────────────────────────────────────────────────
BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo "")"
[[ -n "$BRANCH" ]]        || die "detached HEAD — checkout a feature branch first"
[[ "$BRANCH" != "$BASE" ]] || die "on base branch '${BASE}' — nothing to finish"

if ! git diff --quiet || ! git diff --cached --quiet; then
  die "uncommitted changes — commit or stash before finishing"
fi

ahead="$(git rev-list --count "${BASE}..HEAD" 2>/dev/null || echo 0)"
[[ "$ahead" -gt 0 ]] || die "no commits ahead of '${BASE}' — nothing to land"
```

Then `chmod +x scripts/finish-session`.

- [ ] **Step 4: Run to verify the guard passes**

Run: `scripts/check`
Expected: PASS through the argument-guard block (the `--title` assertion passes because `require_arg_value` fires during parsing, before `require_cmd`/preconditions). `finish-session --help` also passes the help smoke loop.

- [ ] **Step 5: Commit**

```bash
git add scripts/finish-session scripts/check
git commit -m "feat(finish-session): skeleton — arg parsing, preconditions, help" -- scripts/finish-session scripts/check
```

---

### Task 2: Offline `--dry-run` planner + PR-text derivation

**Files:**
- Modify: `scripts/finish-session` (append derivation + dry-run block after preconditions)
- Modify: `scripts/check` (add dry-run smoke test)

**Interfaces:**
- Consumes: globals from Task 1 (`BRANCH`, `BASE`, `STRATEGY`, `DRAFT`, `DO_MERGE`, `WAIT`, `TITLE`, `BODY`, `ahead`).
- Produces: `derive_title()` (branch topic → Title Case), `merge_flag` (`--squash|--merge|--rebase`), and a `--dry-run` code path that prints the plan and `exit 0` before any `gh` call.

- [ ] **Step 1: Write the failing test** — add to `scripts/check` after the `new-project` dry-run smoke check (after line ~86). Note the `trap`-based cleanup is scoped to a `mktemp -d` path:

```bash
echo "==> finish-session dry-run smoke check (offline)"
FS_TMP="$(mktemp -d)"
trap 'rm -rf "$FS_TMP"' EXIT
(
  cd "$FS_TMP"
  git init -q -b main
  git -c user.email=t@e -c user.name=t commit -q --allow-empty -m "base"
  git checkout -q -b agent/demo/20260714-demo-topic
  git -c user.email=t@e -c user.name=t commit -q --allow-empty -m "work commit"
  "${SCRIPT_DIR}/finish-session" --dry-run --base main
) >"$FS_TMP/out.txt" 2>&1 || { cat "$FS_TMP/out.txt"; die "finish-session --dry-run failed"; }
grep -q 'gh pr merge agent/demo/20260714-demo-topic --auto --squash --delete-branch' "$FS_TMP/out.txt" \
  || { cat "$FS_TMP/out.txt"; die "dry-run missing expected auto-merge command"; }
grep -q 'PR title: Demo topic' "$FS_TMP/out.txt" \
  || { cat "$FS_TMP/out.txt"; die "dry-run missing derived title 'Demo topic'"; }
```

- [ ] **Step 2: Run to verify it fails**

Run: `scripts/check`
Expected: FAIL — `finish-session --dry-run failed` (the script has no dry-run block yet, so it falls through to unwritten live code / exits without the expected output).

- [ ] **Step 3: Implement derivation + dry-run block** — append to `scripts/finish-session` after the preconditions:

```bash
# ── Derive PR title/body ─────────────────────────────────────────────────────
derive_title() {
  local topic="${BRANCH##*/}"                                   # last path segment
  topic="${topic#[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-}"    # strip YYYYMMDD-
  topic="${topic//-/ }"                                         # de-slug
  local first="${topic:0:1}"
  printf '%s%s' "$(printf '%s' "$first" | tr '[:lower:]' '[:upper:]')" "${topic:1}"
}

[[ -n "$TITLE" ]] || TITLE="$(derive_title)"
[[ -n "$BODY" ]]  || BODY="$(git log "${BASE}..HEAD" --pretty=format:'- %s')"

merge_flag="--${STRATEGY}"

# ── Dry-run: print the plan from local state only (no gh calls) ───────────────
if [[ "$DRY_RUN" == true ]]; then
  echo "PR title: ${TITLE}"
  echo "[dry-run] git push -u origin ${BRANCH}   (only if no upstream / ahead)"
  echo "[dry-run] gh pr create --base ${BASE} --head ${BRANCH} --title \"${TITLE}\" --body <${ahead} commit(s)>"
  if [[ "$DRAFT" == true ]]; then
    echo "[dry-run] --draft: create draft PR and stop (no auto-merge)"
  elif [[ "$DO_MERGE" == false ]]; then
    echo "[dry-run] --no-merge: ensure PR only (no auto-merge)"
  else
    echo "[dry-run] gh pr merge ${BRANCH} --auto ${merge_flag} --delete-branch"
    if [[ "$WAIT" == true ]]; then
      echo "[dry-run] wait for merge, then: git checkout ${BASE} && git pull --ff-only && git branch -d ${BRANCH}"
    else
      echo "[dry-run] --no-wait: enable auto-merge and return"
    fi
  fi
  exit 0
fi
```

- [ ] **Step 4: Run to verify it passes**

Run: `scripts/check`
Expected: PASS — dry-run prints `PR title: Demo topic` and the `gh pr merge ... --auto --squash --delete-branch` line; smoke test's two `grep -q` checks succeed.

- [ ] **Step 5: Commit**

```bash
git add scripts/finish-session scripts/check
git commit -m "feat(finish-session): offline dry-run planner + PR-text derivation" -- scripts/finish-session scripts/check
```

---

### Task 3: Live path — push, ensure PR, auto-merge, wait, cleanup

**Files:**
- Modify: `scripts/finish-session` (append the live path after the dry-run block)

**Interfaces:**
- Consumes: globals + `merge_flag`, `TITLE`, `BODY` from Task 2.
- Produces: the executed close-out flow. No new test (async network path is dogfood-verified); the dry-run smoke from Task 2 already asserts the planned commands.

- [ ] **Step 1: Implement the live path** — append to `scripts/finish-session`:

```bash
# ── Ensure pushed (never force) ──────────────────────────────────────────────
if ! git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
  run git push -u origin "$BRANCH"
elif [[ -n "$(git rev-list '@{upstream}..HEAD' 2>/dev/null)" ]]; then
  run git push
fi

# ── Ensure a PR exists ───────────────────────────────────────────────────────
if gh pr view "$BRANCH" >/dev/null 2>&1; then
  echo "PR already exists for ${BRANCH}"
elif [[ "$DRAFT" == true ]]; then
  run gh pr create --base "$BASE" --head "$BRANCH" --title "$TITLE" --body "$BODY" --draft
else
  run gh pr create --base "$BASE" --head "$BRANCH" --title "$TITLE" --body "$BODY"
fi

pr_url="$(gh pr view "$BRANCH" --json url --jq .url 2>/dev/null || echo "")"

if [[ "$DRAFT" == true ]]; then
  echo "Draft PR ready: ${pr_url}"
  echo "Mark it ready, then re-run finish-session to land it."
  exit 0
fi

if [[ "$DO_MERGE" == false ]]; then
  echo "PR ready (auto-merge not enabled): ${pr_url}"
  exit 0
fi

# ── Enable merge-when-green ───────────────────────────────────────────────────
run gh pr merge "$BRANCH" --auto "$merge_flag" --delete-branch

if [[ "$WAIT" == false ]]; then
  echo "Auto-merge enabled; lands when '${BASE}' checks pass: ${pr_url}"
  exit 0
fi

# ── Wait for merge, then clean up locally ────────────────────────────────────
echo "Waiting for CI + auto-merge on ${pr_url} ..."
while true; do
  state="$(gh pr view "$BRANCH" --json state --jq .state 2>/dev/null || echo "")"
  [[ "$state" == "MERGED" ]] && break
  [[ "$state" == "CLOSED" ]] && die "PR was closed without merging: ${pr_url}"
  if gh pr checks "$BRANCH" 2>/dev/null | grep -qiE '\bfail'; then
    die "required checks failing — PR left open: ${pr_url}"
  fi
  sleep 10
done

echo "Merged. Cleaning up local branch."
run git checkout "$BASE"
run git pull --ff-only
run git branch -d "$BRANCH"
echo "Done. ${BRANCH} landed into ${BASE}."
```

- [ ] **Step 2: Verify nothing regressed**

Run: `scripts/check`
Expected: PASS (all sections, including the Task 2 dry-run smoke — the live code is never reached in dry-run).

- [ ] **Step 3: Shellcheck the script locally if available**

Run: `command -v shellcheck && shellcheck -x scripts/finish-session || echo "shellcheck absent — CI will gate"`
Expected: no findings (or deferred to CI).

- [ ] **Step 4: Commit**

```bash
git add scripts/finish-session
git commit -m "feat(finish-session): live push/PR/auto-merge/wait/cleanup path" -- scripts/finish-session
```

---

### Task 4: `finish-session` skill

**Files:**
- Create: `skills/finish-session/SKILL.md`

**Interfaces:**
- Consumes: nothing (a thin wrapper skill).
- Produces: an 8th validated skill; `scripts/check` must report `8 skill(s) validated`.

- [ ] **Step 1: Create the skill**, mirroring the `agent-session` skill's shape, `allowed-tools: Bash`:

```markdown
---
name: finish-session
description: >
  Close out an agent work session: ensure the branch is pushed, open or reuse a
  PR, land it when CI is green (squash by default), and delete the branch. The
  symmetric partner to agent-session. Use when work on a branch is complete and
  the user says "finish this", "wrap up the session", "open a PR", "land this",
  "merge the branch", or "clean up the branch". Also trigger proactively when a
  branch's work is done, committed, and pushed, and the next step is a PR/merge.
allowed-tools: Bash
---

# finish-session

Runs `~/scripts/finish-session` to close out the current agent branch. It is the
counterpart to `agent-session` (which *starts* a session).

## What it does

1. Verifies you're on a feature branch with a clean tree and commits ahead of
   `main`.
2. Pushes the branch (never force) and opens a PR if one doesn't exist, deriving
   the title from the branch topic and the body from the commit list.
3. Enables merge-when-green via `gh pr merge --auto --squash --delete-branch`.
   This relies on branch protection requiring the `scripts-check` check, so a red
   PR cannot merge.
4. By default **waits** until the PR merges, then deletes the local branch — so
   it feels like one synchronous "land". `--no-wait` returns immediately after
   enabling auto-merge.

## Usage

```bash
# Full land (default): push → PR → merge-when-green → wait → delete branch
~/scripts/finish-session

# Fire-and-forget: enable auto-merge and return
~/scripts/finish-session --no-wait

# Just open the PR, don't merge
~/scripts/finish-session --no-merge

# Preview without doing anything
~/scripts/finish-session --dry-run
```

Override title/body/base/strategy with `--title`, `--body`, `--base`,
`--merge`/`--rebase`. See `~/scripts/finish-session --help`.

## Low-privilege

Never force-pushes, never deletes an unmerged branch (`git branch -d` only), and
makes no admin/branch-protection API calls.
```

- [ ] **Step 2: Verify the skill validates**

Run: `scripts/check`
Expected: PASS with `8 skill(s) validated` and `claude plugin validate: ok`.

- [ ] **Step 3: Commit**

```bash
git add skills/finish-session/SKILL.md
git commit -m "feat(skills): add finish-session skill wrapping the close-out script"
```

---

### Task 5: Docs — README, docs/finish-session.md, CLAUDE.md

**Files:**
- Create: `docs/finish-session.md`
- Modify: `README.md` (scripts + skills tables), `CLAUDE.md` (PR flow + canonical paths)

**Interfaces:** none (documentation).

- [ ] **Step 1: Create `docs/finish-session.md`** mirroring `docs/agent-session.md`:

```markdown
# Finishing a session (PR → land → cleanup)

`scripts/finish-session` is the counterpart to `agent-session`: it takes a
pushed agent branch and drives the "Standard PR flow" to completion.

## Usage

```bash
scripts/finish-session            # push → PR → merge-when-green → wait → delete
scripts/finish-session --no-wait  # enable auto-merge and return
scripts/finish-session --dry-run  # print the plan, do nothing
```

## Behavior

- Aborts unless you're on a feature branch with a clean tree and commits ahead
  of the base (`main`).
- Opens a PR if none exists (title from the branch topic, body from commits).
- Enables `gh pr merge --auto`, which only merges once the required
  `scripts-check` status check passes.
- Default waits for the merge and deletes the local branch; `--no-wait` skips
  the wait.

## Safety

Never force-pushes, never deletes an unmerged branch, no admin API calls. Relies
on branch protection on `main` requiring the `scripts-check` check.
```

- [ ] **Step 2: Update `README.md`** — add to the scripts list and the skills table:
  - Scripts section: `- Session close-out (PR + land + cleanup): `scripts/finish-session``
  - Skills table row: `| `finish-session` | `scripts/finish-session` |`

- [ ] **Step 3: Update `CLAUDE.md`** — in "Standard PR flow", note that `scripts/finish-session` automates steps 1–5; in "Alex's Canonical Paths", add `- Session close-out: `~/scripts/finish-session``.

- [ ] **Step 4: Verify + commit**

Run: `scripts/check`
Expected: PASS.

```bash
git add docs/finish-session.md README.md CLAUDE.md
git commit -m "docs: document finish-session close-out flow"
```

---

## Final: land the branch (dogfood)

- [ ] Run `scripts/check --require-shellcheck` (install shellcheck if missing) — expect all green.
- [ ] Push, then **dogfood**: run `scripts/finish-session` on this very branch to open its PR and land it when `scripts-check` passes. This is the real integration test of the async path. If anything misbehaves, fall back to the manual PR flow and note the fix.
- [ ] On merge, archive both `docs/active/20260714-finish-session.md` and `docs/active/20260714-finish-session-plan.md` to `docs/archive/`.

## Self-Review

- **Spec coverage:** CLI flags (T1), preconditions/guardrails (T1), PR-text derivation (T2), offline dry-run (T2), push/PR/auto-merge/wait/cleanup (T3), skill w/ `allowed-tools: Bash` (T4), check coverage — arg-guard (T1) + dry-run smoke (T2), docs + registration (T5). All spec sections map to a task.
- **Placeholder scan:** every code step contains full code; no TBD/TODO.
- **Type consistency:** `STRATEGY`→`merge_flag="--${STRATEGY}"` used identically in T2 (dry-run) and T3 (live); `BRANCH`/`BASE`/`ahead`/`TITLE`/`BODY` defined in T1–T2 and consumed unchanged in T3.
