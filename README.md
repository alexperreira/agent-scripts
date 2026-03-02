# agent-scripts

Machine-wide agent workflow for Alex Perreira (WSL-first): rules, scripts, and templates that help Codex work consistently across projects.

## What this repo provides

- Machine-wide defaults: `AGENTS.md`
- Project generator: `scripts/new-project`
- Session helper (branch + push + local snapshots): `scripts/agent-session`
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
- `~/AGENTS.md` → `~/Projects/agent-scripts/AGENTS.md`
- `~/CLAUDE.md` → `~/Projects/agent-scripts/AGENTS.md`
- `~/scripts` → `~/Projects/agent-scripts/scripts`
- `~/templates` → `~/Projects/agent-scripts/templates`

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
~/scripts/agent-session --topic "scaffold cli" --push
```

Local snapshots are written to:
- `~/.local/share/agent-logs/<repo>/<session-id>/`

## Local quality checks

Run lightweight syntax + smoke checks:

```bash
scripts/check
```

If you want to enforce ShellCheck in CI or stricter local runs:

```bash
scripts/check --require-shellcheck
```

This repo runs the same strict command in GitHub Actions on `main` pushes and pull requests.

## Notes

- Some environments restrict network access; if `git push` fails here, run it from your local WSL shell.
- WSL “safe delete” recommendation: `trash-put` (from `trash-cli`) or `gio trash`.
