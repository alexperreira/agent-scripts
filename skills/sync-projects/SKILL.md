---
name: sync-projects
description: >
  Clone or fast-forward every owner/repo listed in current-projects into ~/Projects.
  Use when the user wants to sync their repos, clone all projects, set up a new
  machine, or asks to pull everything. Also trigger when a repo turns out to be
  behind or diverged and the user wants the whole set reconciled.
allowed-tools: Bash, Read
---

# sync-projects

Wraps `~/scripts/sync-projects`, which walks the `current-projects` registry (one
`owner/repo` slug per line; `#` comments and blank lines ignored) and either
clones a missing repo or fast-forwards an existing one.

## Running it

Preview first — this touches every repo on the machine:

```bash
~/scripts/sync-projects --dry-run
```

Then:

```bash
~/scripts/sync-projects
```

Flags: `--projects-dir DIR` (default `~/Projects`), `--registry FILE` (default
`<repo-root>/current-projects`).

## What it will not do

The script is deliberately conservative and **skips with a warning** rather than
touching a repo when any of these hold:

- uncommitted changes to tracked files
- the local branch is ahead of its remote
- history has diverged from the remote
- detached HEAD, or no remote-tracking branch
- the target path exists but is not a git repo

It only ever runs `git pull --ff-only`, so it cannot create a merge commit or
lose work. Exit status is non-zero if any repo errored.

## After it runs

Read the summary line (`cloned= updated= up-to-date= skipped= errors=`) back to
the user. For anything skipped, say which repo and why — those need manual
attention, usually an unpushed branch or a dirty tree.

A skipped repo is easy to ignore and easy to regret: a stale local `main` still
reports "up to date with 'origin/main'" until something fetches.

## Adding a project

```bash
echo "owner/repo" >> ~/Projects/agent-scripts/current-projects
```

`new-project` appends the slug automatically when it creates a GitHub remote.
