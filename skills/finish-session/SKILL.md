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
3. Verifies branch protection on the base branch requires the `scripts-check`
   check, and **refuses to auto-merge if it does not** — `--auto` on an
   unprotected branch merges as soon as the PR is mergeable, which means
   immediately, with CI irrelevant. Only then does it enable merge-when-green
   via `gh pr merge --auto --squash --delete-branch`.

   If it refuses, the branch genuinely isn't protected. Either land it manually
   after checking CI (`--no-merge`), or add the ruleset — do not work around it.
4. By default **waits** until the PR merges, then deletes the local branch — so
   it feels like one synchronous "land". `--no-wait` returns immediately after
   enabling auto-merge.

   The wait is bounded — 30 minutes by default, `--timeout SECONDS` to change it
   (`--timeout 0` waits forever). While waiting it aborts only on a *required*
   check whose state is `fail`; a failing optional check does not stop a land
   that auto-merge would complete anyway.

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

# Wait longer than the 30-minute default (queued runners, slow CI)
~/scripts/finish-session --timeout 5400
```

Override title/body/base/strategy with `--title`, `--body`, `--base`,
`--merge`/`--rebase`. See `~/scripts/finish-session --help`.

## After it runs

Report the PR URL, the merge commit SHA, and confirm the branch was deleted.

If it exits non-zero, say what actually happened rather than "the land failed" —
the failure modes are distinct. A **timeout** means the PR did *not* land but
auto-merge is still enabled, so it may land later on its own; report it as
pending, never as landed. A **failing required check** means the PR is still
open. A **closed PR** means someone rejected it.

## Low-privilege

Never force-pushes. It reads branch protection (see step 3) but never changes
it, and makes no other admin API calls.

Local branch deletion is `git branch -d`. A squash merge — the default — leaves
the branch unmerged *by ancestry*, so `-d` always refuses; the script falls back
to `git branch -D` **only** after the wait loop observed the PR in state
`MERGED`. On any other path the branch is left in place.
