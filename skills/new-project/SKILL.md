---
name: new-project
description: >
  Scaffold a new GitHub repo under ~/Projects with CLAUDE.md, docs/MEASUREMENT.md,
  LICENSE, and .gitignore, then register it in current-projects. Use whenever the
  user wants to start a new project, create a new repo, bootstrap a codebase, or
  says "new project". Also trigger when they describe wanting a fresh repo for an
  idea and have not yet created a directory for it.
allowed-tools: Bash, Read
---

# new-project

Wraps `~/scripts/new-project`, which creates `~/Projects/<name>`, renders the
`templates/empty/` scaffold, makes an initial commit on `main`, creates the
GitHub repo via `gh`, pushes, and appends the slug to `current-projects`.

## Before running

Confirm with the user, since this creates a real GitHub repo:

- **Name** — kebab-case; becomes both the directory and the repo name
- **Visibility** — `private` (default) or `public`
- **Stack** — free-form string; seeds a quickstart section in `CLAUDE.md`
- **Description** — one line, used in the README

Check `gh auth status` first. The script needs `git`, `sed`, `date`, and `gh`.

## Running it

Always dry-run first and show the user the output:

```bash
~/scripts/new-project --name <name> --stack "<stack>" --dry-run
```

Then, once they approve:

```bash
~/scripts/new-project --name <name> \
  --visibility private \
  --stack "typescript, node, pnpm" \
  --description "<one line>"
```

Useful flags: `--no-remote` (local only), `--projects-dir` (defaults to
`$HOME/Projects`), `--license mit|none`, `--owner <gh-owner>`.

## Stack-aware scaffolding

`--stack` keywords drive what gets appended to the project's `CLAUDE.md`:

- `typescript` / `ts` / `node` / `pnpm` / `npm` → Node quickstart
- `python` / `py` / `pytest` / `uv` / `pip` → Python quickstart
- `expo` / `react-native` → mobile skills section

Every project also gets `docs/MEASUREMENT.md`.

## Constraints

The script refuses to run if the target directory already exists — it never
overwrites. A non-kebab-case name warns but proceeds.

`--no-remote` skips registry registration entirely, so a local-only project will
not be picked up by `sync-projects` until its slug is added by hand.

## After it runs

Report the created path, the repo URL, and whether the slug landed in
`current-projects`. Do not `cd` into the new repo and start work unless asked.
