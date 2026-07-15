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
