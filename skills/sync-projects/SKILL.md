---
name: sync-projects
description: >
  Clone or fast-forward every owner/repo listed in current-projects into
  /mnt/c/Users/alexa/Projects.
  Use when the user wants to sync their repos, clone all projects, set up a new
  machine, or asks to pull everything. Also trigger when a repo turns out to be
  behind or diverged and the user wants the whole set reconciled.
allowed-tools: Bash, Read
---

# sync-projects

Wraps `~/scripts/sync-projects`, which walks the `current-projects` registry and
either clones a missing repo or fast-forwards an existing one.

Each line is `owner/repo` plus an optional placement column (`#` comments and
blank lines ignored):

```
alexperreira/uluhe                 # → /mnt/c/Users/alexa/Projects/uluhe
alexperreira/parsnip       ext4    # → $HOME/Projects/parsnip
alexperreira/thing         /srv/x  # → /srv/x/thing
```

## Running it

Preview first — this touches every repo on the machine:

```bash
~/scripts/sync-projects --dry-run
```

`--dry-run` still runs `git fetch` (read-only) so the preview reflects the real
remote state. Only `clone` and `pull` are suppressed.

Then:

```bash
~/scripts/sync-projects
```

Flags: `--projects-dir DIR` (default `$AGENT_SCRIPTS_PROJECTS_DIR`, else
`/mnt/c/Users/alexa/Projects`), `--ext4-dir DIR` (default
`$AGENT_SCRIPTS_EXT4_DIR`, else `$HOME/Projects`), `--registry FILE` (default
`<repo-root>/current-projects`).

Most repos live on `/mnt/c` so Cowork can see them; ADR-0001 keeps build-heavy
ones on ext4, where inotify actually fires. The placement column is what keeps
those two facts from colliding — an ext4 repo listed without `ext4` gets cloned
a **second** time onto `/mnt/c`, giving two working trees per project, both
reporting clean, drifting apart silently.

`/mnt/c` is case-insensitive, so two registry slugs whose repo names differ only
in case share one directory. The script warns up front and refuses to touch a
directory whose `origin` does not match the slug. The collision check is
per-root, so the same repo name under two different roots is not flagged.

An unrecognised placement is reported and counted as an error rather than
silently treated as the default.

## What it will not do

The script is deliberately conservative and **skips with a warning** rather than
touching a repo when any of these hold:

- uncommitted changes to tracked files
- the local branch is ahead of its remote
- history has diverged from the remote
- detached HEAD, or no remote-tracking branch
- the target path exists but is not a git repo
- a stale `.git/index.lock` is present (a git process died there)
- the directory's `origin` is a different repo than the registry entry names
- `git fetch` failed (offline or auth)

A **skip** is not an **error**: skips are reported and the run continues at exit
0. A failed clone or a failed `git pull --ff-only` is an error and sets a
non-zero exit.

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
echo "owner/repo" >> /mnt/c/Users/alexa/Projects/agent-scripts/current-projects
```

`new-project` appends the slug automatically when it creates a GitHub remote.
