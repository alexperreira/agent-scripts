# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Machine-wide agent workflow tooling for Alex Perreira (WSL-first): shell scripts, skills, templates, and configuration that agents use across all projects. This is not an application — it's infrastructure.

The `AGENTS.md` file here is the source of truth for machine-wide defaults and is symlinked to `~/AGENTS.md` and `~/CLAUDE.md` by `scripts/bootstrap-home-links`. Editing `AGENTS.md` therefore changes the instructions loaded into every session on this machine.

## Quality checks

```bash
scripts/check                     # syntax + smoke + manifests + shellcheck (if available)
scripts/check --require-shellcheck  # strict; used in CI
```

CI runs on `main` pushes and PRs via `.github/workflows/check.yml`.

`check` discovers bash scripts by shebang rather than by a hardcoded list, so a new script under `scripts/` is covered automatically. It also validates `.claude-plugin/marketplace.json`, every `plugin.json`, and every `SKILL.md` (frontmatter `name` must match its directory name).

## Script architecture

All scripts are plain bash with `set -euo pipefail`. Every script sources `scripts/lib/common.sh` which provides four shared helpers:

- `die <msg>` — print to stderr and exit 1
- `warn <msg>` — print to stderr, continue
- `require_cmd <cmd>` — fail if a command is missing
- `require_arg_value <flag> <value>` — fail if a flag's value is missing or starts with `--`

### Scripts

| Script | Purpose |
|---|---|
| `scripts/new-project` | Create a new GitHub repo under `~/Projects`, scaffold from `templates/empty/`, register in `current-projects` |
| `scripts/agent-session` | Create an agent work branch, snapshot git state to `~/.local/share/agent-logs/<repo>/<session-id>/`, optionally push |
| `scripts/bootstrap-home-links` | Symlink `~/AGENTS.md`, `~/CLAUDE.md`, `~/scripts`, `~/templates`, and each skill into `~/.codex/skills/`. Default is dry-run; pass `--apply` to make changes |
| `scripts/sync-projects` | Clone or fast-forward-pull every `owner/repo` in `current-projects`; skips on uncommitted changes, ahead-of-remote, diverged, or detached HEAD |
| `scripts/setup-claude-mcps` | Register global MCP servers for Claude Code and/or Codex |
| `scripts/check` | Syntax-check all scripts, run `--help` smoke tests, validate plugin manifests and skills, run shellcheck |

## Skills & plugin layout

```
.claude-plugin/marketplace.json        # marketplace: agent-scripts
plugins/alex-workflow/
  .claude-plugin/plugin.json           # plugin: alex-workflow
  skills/<name>/SKILL.md               # one directory per skill
```

Claude Code installs these as a plugin (`/plugin marketplace add ~/Projects/agent-scripts`, then `/plugin install alex-workflow@agent-scripts`); skills are namespaced `alex-workflow:<name>`. Codex has no plugin system, so `bootstrap-home-links` symlinks each skill into `~/.codex/skills/<name>` individually — it must never replace that directory wholesale, because Codex's own bundled skills live there too.

Validate any change with `claude plugin validate .`.

## Secrets

`scripts/setup-claude-mcps` must never pass a secret *value* to `claude mcp add -e` or `codex mcp add --env`: both CLIs persist those values in cleartext into `~/.claude.json` and `~/.codex/config.toml`. Instead it registers a `bash -c` wrapper that sources `~/.secrets` at spawn time, so the key reaches only the server process.

When editing that script, keep `$GITHUB_PAT` single-quoted (`shellcheck disable=SC2016`) — bash inside the wrapper must expand it, not the setup script.

Never read, print, or commit the contents of `~/.secrets`.

## Templates

`templates/empty/` contains `.tmpl` files with `{{VAR}}` tokens that `new-project` renders via `sed`. Variables: `PROJECT_NAME`, `DESCRIPTION`, `TECH_STACK`, `YEAR`, `AUTHOR`, `GITHUB_OWNER`, `WEBSITE`.

`new-project` also appends stack-specific quickstart sections to `AGENTS.md` based on keywords in `--stack` (detects `typescript/ts/node/pnpm/npm` and `python/py/pytest/uv/pip`).

## Key conventions

- No build system, no package manager, no dependencies — pure bash only.
- `current-projects` file format: one `owner/repo` slug per line; `#` comments and blank lines ignored.
- New projects get `AGENTS.md` plus a real `CLAUDE.md` that imports it with `@AGENTS.md`. Not a symlink: Claude Code does not read `AGENTS.md` natively, and symlinks require Developer Mode on the Windows side.
- Branch naming convention for agent work: `agent/<repo>/<YYYYMMDD>-<topic-slug>`.
- Do NOT add a `Co-authored-by: Claude` trailer to commit messages.
