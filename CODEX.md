# CODEX.md — How Codex Should Operate In `agent-scripts`

This repo is for maintaining machine-wide automation and guidance files (not a single app/product). Keep changes small, portable, and easy to reuse across projects.

## Primary artifacts
- `AGENTS.md`: master, cross-project defaults for Alex Perreira.
- `plugins/alex-workflow/skills/`: shared Agent Skills, loaded by Codex via
  symlinks into `~/.codex/skills/` (see `scripts/bootstrap-home-links`).
- `docs/GOAL-AGENTS.md`: reference example to learn from (do not treat as requirements).

## Operating mode
- Be explicit and minimal; prefer the smallest correct change.
- Don't introduce new tooling/dependencies unless clearly justified.
- Avoid OS-specific assumptions; if a workflow differs by OS, document the variants.

## Workflow contract
- Follow `AGENTS.md` for the execution protocol (plan + intended commands + approval).
- When editing text/policy documents, optimize for clarity and long-term maintainability.
- Run `scripts/check` before proposing a change to any script.

## Secrets
- Never write an API key into `~/.codex/config.toml`. Keys live in `~/.secrets`
  (mode `600`) and reach MCP servers through the spawn-time wrapper that
  `scripts/setup-claude-mcps` registers.

## Output format after changes
- Summary (what/why)
- Files changed
- Commands to run (if any)
- Notes / risks / follow-ups
