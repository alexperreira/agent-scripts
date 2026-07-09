# Project generator

This repo ships a simple generator for new projects that live under `~/Projects` (WSL-first) and publish to GitHub under `@alexperreira`.

## What it does

- Creates `~/Projects/<name>`
- Writes a minimal starter layout (README, `.gitignore`, project-scoped `AGENTS.md`, a `CLAUDE.md` that imports it via `@AGENTS.md`, optional MIT `LICENSE`)
- Uses `--stack` to seed the project `AGENTS.md` with suggested commands for common stacks (currently Node/TS and Python).
- Initializes a git repo on `main` with an initial commit
- Creates `https://github.com/alexperreira/<name>.git` via `gh` and pushes (unless `--no-remote`)

## Usage

```bash
scripts/new-project --name <repo-name> \
  --visibility private \
  --stack "typescript, node, pnpm"
```

See all options:

```bash
scripts/new-project --help
```

## Defaults

- `--visibility`: `private`
- `--projects-dir`: `$HOME/Projects`
- `--owner`: `alexperreira`
- `--license`: `mit`

## Notes

- Prefer keeping repos on the WSL filesystem (not under `/mnt/c`) for performance.
- Use `--no-remote` to create a local-only repo (useful for testing or offline work).
  Local-only repos are **not** registered in `current-projects`, so `sync-projects`
  will not see them until the slug is added by hand.
- `CLAUDE.md` is a real file rather than a symlink to `AGENTS.md`: Claude Code does
  not read `AGENTS.md` natively, and symlinks need Developer Mode on Windows.
