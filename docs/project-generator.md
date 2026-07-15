# Project generator

This repo ships a simple generator for new projects that live under `~/Projects` (WSL-first) and publish to GitHub under `@alexperreira`.

## What it does

- Creates `~/Projects/<name>`
- Writes a minimal starter layout (README, `.gitignore`, project-scoped `CLAUDE.md`, optional MIT `LICENSE`)
- Uses `--stack` to seed the project `CLAUDE.md` with suggested commands for common stacks (currently Node/TS and Python).
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

## Environment overrides

The identity defaults are env-configurable so the generator works on other
machines/accounts without editing the script. Precedence is **CLI flag > env
var > built-in default**:

| Env var | Sets | Default |
|---|---|---|
| `AGENT_SCRIPTS_OWNER` | GitHub owner/org (same as `--owner`) | `alexperreira` |
| `AGENT_SCRIPTS_AUTHOR` | Author name in `LICENSE` | `Alex Perreira` |
| `AGENT_SCRIPTS_WEBSITE` | Site/blog URL | `alexhacks.net` |

## Notes

- Prefer keeping repos on the WSL filesystem (not under `/mnt/c`) for performance.
- Use `--no-remote` to create a local-only repo (useful for testing or offline work).
