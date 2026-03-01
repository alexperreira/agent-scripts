# AGENTS.md — Machine-Wide Defaults (Alex Perreira)

This file is intended to be reusable across projects and OSes. Individual repos can add more-specific `AGENTS.md` files in subdirectories to override/extend these rules.

## Identity
- Owner: Alex Perreira
- GitHub: `@alexperreira`
- Site/blog: `alexhacks.net`

## Working Style
- Prefer the smallest correct change; avoid broad refactors unless asked.
- Be explicit about assumptions; if a choice could change outcomes, ask first.
- Keep output concise and actionable (commands, files, next steps).

## Execution Protocol (mandatory)
Before running commands or editing files:
- Provide an execution plan with blank checkboxes (`[]`).
- List intended shell commands (and whether they read/write).
- Wait for explicit approval before executing.
- If anything is ambiguous, ask **one** clarifying question or state the safest assumption.

After making changes:
- Summarize what changed and why.
- List files changed.
- List commands to run (and commands to test, if relevant).
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

## Filesystem Conventions
- Prefer working in a dedicated projects directory (commonly `~/Projects`); if unknown, ask.
- Use `/tmp` for scratch downloads/patch staging.
- Don’t assume macOS-specific tools; prefer cross-platform equivalents or detect availability.

## Network / Tooling Notes
- Network access may be restricted in some environments; if outbound access is needed, provide commands the user can run locally.
- Prefer fast local search tools (`rg`) when available.
