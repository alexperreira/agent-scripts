---
name: new-project
description: >
  Scaffold a new GitHub repo under /mnt/c/Users/alexa/Projects with CLAUDE.md, docs/MEASUREMENT.md,
  LICENSE, and .gitignore, then register it in current-projects. Use whenever the
  user wants to start a new project, create a new repo, bootstrap a codebase, or
  says "new project". Also trigger when they describe wanting a fresh repo for an
  idea and have not yet created a directory for it.
allowed-tools: Bash, Read
---

# new-project

Wraps `~/scripts/new-project`, which creates
`/mnt/c/Users/alexa/Projects/<name>`, renders the
`templates/empty/` scaffold, makes an initial commit on `main`, creates the
GitHub repo via `gh`, pushes, and appends the slug to `current-projects`.

## Before running

Confirm with the user, since this creates a real GitHub repo:

- **Name** — kebab-case; becomes both the directory and the repo name
- **Visibility** — `private` (default) or `public`
- **Stack** — free-form string; seeds a quickstart section in `CLAUDE.md`
- **Description** — one line, used in the README

The script checks its own preconditions — `git`, `sed`, `date`, and (unless
`--no-remote`) that `gh` is authenticated — **before** it creates anything, so a
failure leaves no directory behind. A missing global `user.email` is a warning,
not an error, since git falls back to `user@hostname`. If something does fail
partway through, it removes the partial tree so the retry works.

## Running it

Always dry-run first and show the user the output. The dry-run runs every
precondition, so it genuinely can fail — a clean dry-run means the real run
will get at least as far as the GitHub call:

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
`$AGENT_SCRIPTS_PROJECTS_DIR`, else `/mnt/c/Users/alexa/Projects`),
`--license mit|none`, `--owner <gh-owner>`.

## Stack-aware scaffolding

`--stack` is split into whole words (on anything non-alphanumeric), and those
words drive what gets appended to the project's `CLAUDE.md`:

- `ts` / `typescript` / `js` / `javascript` / `node` / `nodejs` / `pnpm` /
  `npm` / `yarn` / `bun` → Node quickstart
- `py` / `python` / `python3` / `pytest` / `uv` / `pip` / `poetry` / `ruff` /
  `django` / `flask` / `fastapi` → Python quickstart
- `expo` / `mobile` / `ios` / `android`, or `react` together with `native`
  → mobile skills section

Matching is on whole words, not substrings, so `nats` no longer reads as `ts`
and `copy-on-write` no longer reads as `py`.

Every project also gets `docs/MEASUREMENT.md`.

## Constraints

The script refuses to run if the target directory already exists — it never
overwrites an existing tree. A non-kebab-case name warns but proceeds.

Repos are created on `/mnt/c` and get `core.fileMode false`, because that
filesystem cannot represent the executable bit. Set a script's mode in the
index with `git update-index --chmod=+x <path>`.

`--no-remote` skips registry registration entirely, so a local-only project will
not be picked up by `sync-projects` until its slug is added by hand.

## After it runs

Report the created path, the repo URL, and whether the slug landed in
`current-projects`.

Registering a project modifies `current-projects`, which is tracked in
`agent-scripts` — the script does not commit it. Until it is committed,
`sync-projects` skips `agent-scripts` with "has uncommitted changes", so the
orchestration repo quietly stops syncing itself. The script prints the exact
commit command; pass it on.

Stop after reporting. Wait for the user to say what to build.
