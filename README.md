# agent-scripts

Machine-wide workflow for Alex Perreira (WSL-first): rules, scripts, and templates that help Claude Code work consistently across projects.

## What this repo provides

- Machine-wide defaults: `CLAUDE.md`
- Shared Agent Skills: `skills/`
- Project generator: `scripts/new-project`
- Session helper (branch + push + local snapshots): `scripts/agent-session`
- Multi-repo sync: `scripts/sync-projects` (driven by `current-projects`)
- MCP server registration: `scripts/setup-claude-mcps`
- Bootstrap symlinks into `~`: `scripts/bootstrap-home-links`
- Templates used by generators: `templates/`

## Assumptions

- Windows host + WSL2 Ubuntu
- You work inside WSL (and occasionally use `/mnt/c/Users/alexa/...` for downloads)

## Install (new machine)

```bash
mkdir -p ~/Projects
git clone https://github.com/alexperreira/agent-scripts.git ~/Projects/agent-scripts
cd ~/Projects/agent-scripts
scripts/bootstrap-home-links --apply
```

This creates/updates:
- `~/CLAUDE.md` → `~/Projects/agent-scripts/CLAUDE.md`
- `~/scripts` → `~/Projects/agent-scripts/scripts`
- `~/templates` → `~/Projects/agent-scripts/templates`
- `~/.codex/skills/<name>` → each skill in `skills/`

Then install the skills into Claude Code as a plugin:

```
/plugin marketplace add ~/Projects/agent-scripts
/plugin install alex-workflow@agent-scripts
```

## Skills

One `SKILL.md` source of truth per skill, loaded by both agents — as a plugin in
Claude Code (namespaced `alex-workflow:<name>`), and via per-skill symlinks in
Codex, which has no plugin system.

| Skill | What it covers |
|---|---|
| `new-project` | `scripts/new-project` |
| `agent-session` | `scripts/agent-session` |
| `sync-projects` | `scripts/sync-projects` |
| `expo-project-scaffold` | Expo app structure, routing, auth |
| `expo-build-deploy` | EAS Build, OTA updates, store submission |
| `rn-component-patterns` | React Native component conventions |
| `rn-platform-gotchas` | iOS/Android platform differences |

Add one by creating `skills/<name>/SKILL.md` with `name` and `description`
frontmatter. `scripts/check` enforces that the frontmatter `name` matches the
directory name. Skills cost tokens in every session — check with
`claude plugin details alex-workflow`.

## MCP servers

```bash
scripts/setup-claude-mcps --dry-run   # preview
scripts/setup-claude-mcps             # register for Claude Code + Codex
scripts/setup-claude-mcps --replace   # re-register, overwriting existing entries
```

Secrets are read from `~/.secrets` and are **never written into
`~/.claude.json` or `~/.codex/config.toml`**. Servers needing a key are
registered as a `bash -c` wrapper that sources `~/.secrets` at spawn time, so the
key exists on disk in exactly one file. Keep it at mode `600`.

If a key was previously stored in plaintext by an older version of this script,
rotate it, update `~/.secrets`, then re-run with `--replace`.

## Usage

### Create a new project repo (GitHub)

```bash
~/scripts/new-project --name my-new-repo --visibility private --stack "typescript, node, pnpm"
```

Defaults:
- `--visibility` is `private`
- `--license` is `mit`
- GitHub owner is `alexperreira`

### Start an agent work session (branch + push)

```bash
git fetch origin          # never branch from a stale base
~/scripts/agent-session --topic "scaffold cli" --push
```

Local snapshots are written to:
- `~/.local/share/agent-logs/<repo>/<session-id>/`

### Sync every registered project

```bash
~/scripts/sync-projects --dry-run
~/scripts/sync-projects
```

## Local quality checks

Run lightweight syntax + smoke checks:

```bash
scripts/check
```

Scripts are discovered by shebang, so a new script under `scripts/` is syntax-
checked, `--help`-smoke-tested, and shellchecked automatically. The plugin
manifests and every `SKILL.md` are validated too.

If you want to enforce ShellCheck in CI or stricter local runs:

```bash
scripts/check --require-shellcheck
```

This repo runs the same strict command in GitHub Actions on `main` pushes and pull requests.

## Notes

- Some environments restrict network access; if `git push` fails here, run it from your local WSL shell.
- WSL “safe delete” recommendation: `trash-put` (from `trash-cli`) or `gio trash`.
