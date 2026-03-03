# AGENTS.md — Machine-Wide Defaults (Alex Perreira)

This file is intended to be reusable across projects. Individual repos can add more-specific `AGENTS.md` files in subdirectories to override/extend these rules.

## Identity

- Owner: Alex Perreira
- GitHub: `@alexperreira`
- Site/blog: `alexhacks.net`

## Environment (WSL-first)

- Primary setup: Windows host + WSL2 Ubuntu.
- Work exclusively inside WSL unless explicitly requested otherwise.
- Windows filesystem access is via `/mnt/c/...` (commonly `/mnt/c/Users/alexa/Downloads`, etc.).

## Scope & Search Roots

Paths I may freely read without asking:

- Current repo/working directory
- `~/Projects/**`, `/tmp/**`, `~/scripts/**`, `~/templates/**`
- `/mnt/c/Users/alexa/Downloads/**`

Ask before accessing:

- `~/Documents/**`, other home directories, external mounts

Never access (unless explicitly instructed with clear reason):

- `~/.ssh/**`, `~/.gnupg/**`, password managers, browser profiles, cloud credentials

## Orchestration Context

This file lives at the WSL root level (`~/AGENTS.md`) and is primarily used for:

- Bootstrapping new projects via `~/scripts/new-project`
- Cross-project tasks and automation
- Agent sessions that span multiple repos

When working inside a specific project, defer to that project's `AGENTS.md` if present.

## Working Style

- Prefer the smallest correct change; avoid broad refactors unless asked.
- Be explicit about assumptions; if a choice could change outcomes, ask first.
- Keep output concise and actionable (commands, files, next steps).

## Communication Style

- Be direct; skip unnecessary preamble
- When presenting options, use numbered lists for easy selection
- For multi-step plans, use checkboxes: `- [ ] Step one`
- If blocked or uncertain, say so immediately rather than guessing

## Execution Protocol (default autonomy)

Read-only actions (no approval required):

- I may run clearly read-only commands to inspect and understand the workspace (e.g., `ls`, `rg`, `sed -n`, `cat`, `git status`, `git diff`, `git log`).
- I may also run `npm test` and `pnpm lint` (they may write caches/artifacts, but should not change source).
- I’ll narrate what I’m checking and why.

Write/actions that change state (approval required first):

- Any file edits, dependency installs, running generators/formatters across many files, migrations, starting long-running services, network calls, or git actions beyond read-only inspection.
- Before doing any of the above: provide a checkbox plan + intended commands, then wait for explicit approval.

After making changes:

- Summarize what changed and why.
- List files changed.
- Call out any risks/edge cases.

## Safety & Guardrails (non-negotiable)

- NEVER edit `.env` files or environment-variable files; only the user may change them.
- ABSOLUTELY NEVER run destructive operations without explicit written instruction in this conversation:
  - Examples: `rm`, `rmdir`, `del`, `git reset --hard`, `git clean`, `git restore`, `mkfs`, `dd`.
- Prefer reversible actions (create new files, additive config) over destructive ones.
- If a task appears to require deletion to “fix lint/type errors”, stop and ask first.

## Collaboration Rules

- Don’t revert or delete work you didn’t author; coordinate instead.
- If you detect signs of in-flight work (uncommitted changes, conflicting edits), stop and ask.
- Moving/renaming/restoring files is allowed when it’s clearly within scope.

## Git Workflow

- Default to read-only git inspection: `git status`, `git diff`, `git log`.
- Don’t create/switch branches unless explicitly asked.
- Don’t commit unless explicitly asked.
- Don’t push unless explicitly asked.
- Never amend commits without explicit approval.
- When a commit is requested:
  - Double-check `git status` before staging/committing.
  - Stage only files you changed (tracked files only unless user says to add new ones).
  - Keep commits atomic and list each path explicitly:
    - `git commit -m "<scoped message>" -- path/to/file1 path/to/file2`
  - Quote any git paths containing brackets/parentheses so the shell doesn’t treat them as globs/subshells.
- When running `git rebase`, avoid opening editors: use `GIT_EDITOR=:` and `GIT_SEQUENCE_EDITOR=:` (or `--no-edit`).

## Git Policy (default for agent work)

- Default workflow: create a branch, commit early/often, and push the branch for cross-machine continuity.
  - Branch naming suggestion: `agent/<repo>/<YYYYMMDD>-<topic>`
- PRs are recommended by default and required for higher-risk changes:
  - Required: behavior changes (scripts/automation/generators), dependency/tooling changes, security-sensitive changes, large diffs, or repos with collaborators/branch protections.
  - Optional: docs-only and small, low-risk changes in personal repos.
- Project-scoped `AGENTS.md` may tighten/override this policy.

## Filesystem Conventions

- Prefer working in a dedicated projects directory inside WSL (commonly `~/Projects`); if unknown, ask.
- Use `/tmp` for scratch downloads/patch staging.
- Prefer Linux CLI tools; avoid macOS-specific commands unless explicitly requested.

## Network / Tooling Notes

- Network access may be restricted in some environments; if outbound access is needed, provide commands the user can run locally.
- Prefer fast local search tools (`rg`) when available.

## Tools

### Safe delete (WSL)

- Prefer a trash-based delete over permanent deletion.
- If available: `trash-put <path>` (from `trash-cli`).
  - Install (Ubuntu): `sudo apt-get update && sudo apt-get install -y trash-cli`
- Fallback: `gio trash <path>` (often available via `gvfs`).

### Core CLI

- Search: `rg`
- GitHub: `gh`
- Session persistence (optional): `tmux`

### Alex’s Canonical Paths

- Scripts: `~/scripts` (symlinked to your canonical scripts repo)
- Templates: `~/templates` (symlinked to your canonical templates repo)
- Project generator: `~/scripts/new-project`
- Agent session helper: `~/scripts/agent-session` (branch + push + local snapshots)
- Bootstrap symlinks: `~/scripts/bootstrap-home-links --apply`

### Slash commands

- Global: `~/.codex/prompts/`
- Repo-local (optional): `docs/slash-commands/`

# CLAUDE.md — Machine-Wide Defaults

See `AGENTS.md` in this directory for full instructions. All rules there apply.

## Claude-Specific Notes

- Slash commands section does not apply (Codex-specific)
- For project bootstrapping, use `~/scripts/new-project` as documented

## Commit Message Policy

- Do NOT add a `Co-authored-by: Claude` trailer (or any AI attribution line) to commit messages.
- Commit messages should be clean, author-only, and not reference AI tooling.
