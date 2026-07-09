# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Machine-wide agent workflow tooling for Alex Perreira (WSL-first): shell scripts, templates, and configuration that agents use across all projects. This is not an application — it's infrastructure.

The `AGENTS.md` file here is the source of truth for machine-wide defaults and is symlinked to `~/AGENTS.md` and `~/CLAUDE.md` by `scripts/bootstrap-home-links`.

## Quality checks

```bash
scripts/check                     # syntax + smoke + shellcheck (if available)
scripts/check --require-shellcheck  # strict; used in CI
```

CI runs on `main` pushes and PRs via `.github/workflows/check.yml`.

## Script architecture

All scripts are plain bash with `set -euo pipefail`. Every script sources `scripts/lib/common.sh` which provides three shared helpers:

- `die <msg>` — print to stderr and exit 1
- `require_cmd <cmd>` — fail if a command is missing
- `require_arg_value <flag> <value>` — fail if a flag's value is missing or starts with `--`

### Scripts

| Script | Purpose |
|---|---|
| `scripts/new-project` | Create a new GitHub repo under `~/Projects`, scaffold from `templates/empty/`, register in `current-projects` |
| `scripts/agent-session` | Create an agent work branch, snapshot git state to `~/.local/share/agent-logs/<repo>/<session-id>/`, optionally push |
| `scripts/bootstrap-home-links` | Symlink `~/AGENTS.md`, `~/CLAUDE.md`, `~/scripts`, `~/templates` to this repo. Default is dry-run; pass `--apply` to make changes |
| `scripts/sync-projects` | Clone or fast-forward-pull every `owner/repo` in `current-projects`; skips on uncommitted changes, ahead-of-remote, diverged, or detached HEAD |
| `scripts/setup-claude-mcps` | Register global MCP servers for Claude Code and/or Codex; reads API keys from `~/.secrets` |
| `scripts/check` | Syntax-check all scripts, run `--help` smoke tests, run shellcheck |

### Templates

`templates/empty/` contains `.tmpl` files with `{{VAR}}` tokens that `new-project` renders via `sed`. Variables: `PROJECT_NAME`, `DESCRIPTION`, `TECH_STACK`, `YEAR`, `AUTHOR`, `GITHUB_OWNER`, `WEBSITE`.

`new-project` also appends stack-specific quickstart sections to `AGENTS.md` based on keywords in `--stack` (detects `typescript/ts/node/pnpm/npm` and `python/py/pytest/uv/pip`).

## Key conventions

- No build system, no package manager, no dependencies — pure bash only.
- `current-projects` file format: one `owner/repo` slug per line; `#` comments and blank lines ignored.
- New projects get `AGENTS.md` + a `CLAUDE.md` symlink pointing to it (`ln -s AGENTS.md CLAUDE.md`).
- Branch naming convention for agent work: `agent/<repo>/<YYYYMMDD>-<topic-slug>`.
