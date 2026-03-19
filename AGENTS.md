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

## Planning & Task Decomposition

When planning product specs, program specs, or multi-step execution:

### Task Files

Create a task file per logical feature branch in `docs/active/` (or `/tmp/tasks/`
for ephemeral work), named `<YYYYMMDD>-<feature-slug>.md`. Move completed task
docs (or a summarized version) to `docs/archive/`. Each file should include:

- **Goal** — one-sentence objective
- **Dependencies** — task files that must complete first (list by filename)
- **Steps** — checkbox list
- **Parallel-safe notes** — explicitly call out which steps can run concurrently
- **Outputs** — files/artifacts produced

### Sequencing Rules

- **Sequential** — tasks that share mutable state (same file, schema, config)
- **Parallel-safe** — tasks on independent files, services, or branches
- No listed dependency → implicitly parallel-safe with other dependency-free tasks

### Example

```md
# Feature: <name>

**Goal:** <one sentence>
**Depends on:** `<other-task>.md` (must complete first)

## Steps

- [ ] Step A — sequential (writes shared config)
- [ ] Step B — parallel-safe (isolated service)
- [ ] Step C — sequential after Step A

## Outputs
- path/to/file1
```

### Before Executing

Present the full task breakdown (with dependency order) and wait for explicit
approval before touching any files.

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

## Git Workflow & Policy

### Inspection defaults (all sessions)

- Default to read-only inspection: `git status`, `git diff`, `git log`.
- Never amend commits without explicit approval.
- Never add "Co-Authored-By: Claude" or any AI attribution to commit messages.
- When running `git rebase`, avoid opening editors: use `GIT_EDITOR=:` and
  `GIT_SEQUENCE_EDITOR=:` (or `--no-edit`).

### Committing

- **Interactive sessions:** don’t commit unless explicitly asked.
- **Agent work sessions** (feature branch + task plan): commit in logical chunks;
  committing is implicit to the workflow.
- Double-check `git status` before staging/committing.
- Stage only files you changed (tracked files only unless user says to add new ones).
- Keep commits atomic and list each path explicitly:
  - `git commit -m "<scoped message>" -- path/to/file1 path/to/file2`
- Quote any git paths containing brackets/parentheses so the shell doesn’t treat
  them as globs/subshells.

### Branching & pushing (agent work defaults)

- Default: create a branch via `agent-session` (see ## Agent Session Startup),
  commit in logical chunks, and push for cross-machine continuity.
- Don’t create/switch branches or push manually unless `agent-session` is
  unavailable or `--no-checkout` was used.
- Branch naming: `agent/<repo>/<YYYYMMDD>-<topic>` (handled automatically by `agent-session`).

### PR policy

PRs are recommended by default and **required** for:
- Behavior changes (scripts/automation/generators)
- Dependency or tooling changes
- Security-sensitive changes
- Large diffs or repos with collaborators/branch protections

PRs are **optional** for docs-only and small, low-risk changes in personal repos.

### Standard PR flow

1. Push the branch (`git push -u origin <branch>`)
2. Open a PR (`gh pr create ...`)
3. Merge (`gh pr merge --squash` or `--merge` as appropriate)
4. Delete the remote branch (auto if configured; otherwise `git push origin --delete <branch>`)
5. Delete the local branch (`git branch -d <branch>`)

Project-scoped `AGENTS.md` may tighten or override any of the above.

## Agent Session Startup

Before making any file changes on a branchable task, run `agent-session` to
create or resume the correct feature branch and capture a local session snapshot.

### When to branch

Use the same criteria as **PR required** in `## Git Workflow & Policy` above.
Skip branching (`--no-checkout`) for read-only investigation sessions.

### Standard invocation

```bash
~/scripts/agent-session --topic "<short-topic>" --push
```

Creates `agent/<repo>/<YYYYMMDD>-<topic-slug>` (or checks it out if it exists),
saves a snapshot to `~/.local/share/agent-logs/`, and sets upstream.

### Resuming an existing branch

The command is idempotent — existing branch is checked out, not re-created.
To target a branch explicitly:

```bash
~/scripts/agent-session --topic "<topic>" --branch "agent/<repo>/<date>-<slug>" --push
```

### Investigation-only sessions

```bash
~/scripts/agent-session --topic "<topic>" --no-checkout
```

### Sequencing with Planning

- Run `agent-session` once per feature branch, not per task step.
- Parallel-safe tasks on the **same branch** share one session.
- Tasks on **separate branches** each get their own `agent-session` call.

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
- Project registry: `~/Projects/agent-scripts/current-projects`
- Project sync: `~/scripts/sync-projects`

## Current Projects

The canonical list of all projects on this machine lives in `~/Projects/agent-scripts/current-projects`.

**Format:** one `owner/repo` GitHub slug per line; blank lines and `#` comments are ignored.

**To add a project manually:**
```bash
echo "owner/repo" >> ~/Projects/agent-scripts/current-projects
```

**To sync all projects** (clone missing, pull existing):
```bash
~/scripts/sync-projects
```
Or with options:
```bash
~/scripts/sync-projects --dry-run          # preview only
~/scripts/sync-projects --projects-dir /tmp/work  # alternate dir
```

**Automatic registration:** `scripts/new-project` appends the new slug to `current-projects` automatically after a successful GitHub push. No manual step needed for new projects.

**Guardrails in `sync-projects`:**
- Local branch ahead of remote → skip pull, print warning (push or PR manually)
- Uncommitted changes → skip pull, print warning
- Diverged history → skip pull, print warning
- Non-git directory with same name → skip, print warning

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
