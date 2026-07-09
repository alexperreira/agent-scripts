---
name: agent-session
description: >
  Create or resume an agent work branch (agent/<repo>/<YYYYMMDD>-<topic>) and
  snapshot git state to ~/.local/share/agent-logs. Use before making file changes
  on any branchable task, when starting agent work, or when the user says "start a
  session" or "make a branch for this". Also trigger proactively when about to edit
  files on main for anything that would need a PR.
allowed-tools: Bash
---

# agent-session

Wraps `~/scripts/agent-session`. Run this **once per feature branch**, before the
first file change — not once per task step.

## Check the base first

`git status` reporting "up to date with 'origin/main'" only compares against the
last fetch. Run `git fetch origin` before branching, or you can silently build on
a stale base and produce a PR that fights work already merged upstream.

```bash
git fetch origin && git status -sb
```

## When to branch

Branch for anything that would need a PR: behavior changes, dependency or tooling
changes, security-sensitive edits, large diffs, or repos with collaborators. Skip
branching with `--no-checkout` for read-only investigation.

## Running it

```bash
~/scripts/agent-session --topic "<short topic>" --push
```

This creates or checks out `agent/<repo>/<YYYYMMDD>-<topic-slug>`, writes a
snapshot (`meta.txt`, `status.txt`, `log.txt`, diffs) to
`~/.local/share/agent-logs/<repo>/<session-id>/`, and sets upstream.

The command is idempotent: an existing branch is checked out, not re-created, so
resuming prior work is the same invocation with the same topic.

Investigation only, no branch:

```bash
~/scripts/agent-session --topic "<topic>" --no-checkout
```

## Constraints

`--push` requires a checkout, so it cannot be combined with `--no-checkout`, and
it fails if the remote is not configured. `--diff` accepts `stat` (default),
`full`, or `none`; use `full` to capture the working-tree patch before touching
anything.

Parallel-safe tasks on the same branch share one session. Tasks on separate
branches each get their own invocation.

## After it runs

Report the branch name and the snapshot directory, then proceed with the task.
