# CODEX.md — How Codex Should Operate In `agent-scripts`

This repo is for maintaining machine-wide automation and guidance files (not a single app/product). Keep changes small, portable, and easy to reuse across projects.

## Primary artifacts
- `AGENTS.md`: master, cross-project defaults for Alex Perreira.
- `docs/GOAL-AGENTS.md`: reference example to learn from (do not treat as requirements).

## Operating mode
- Be explicit and minimal; prefer the smallest correct change.
- Don’t introduce new tooling/dependencies unless clearly justified.
- Avoid OS-specific assumptions; if a workflow differs by OS, document the variants.

## Workflow contract
- Follow `AGENTS.md` for the execution protocol (plan + intended commands + approval).
- When editing text/policy documents, optimize for clarity and long-term maintainability.

## Output format after changes
- Summary (what/why)
- Files changed
- Commands to run (if any)
- Notes / risks / follow-ups
