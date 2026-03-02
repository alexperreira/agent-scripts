# Agent sessions (branch + push + local snapshots)

Goal: keep a clear history of agent work and make it easy to continue on another machine.

## Default workflow (recommended)

- Create a branch for the task
- Commit early/often
- Push the branch to GitHub
- Use a PR for higher-risk changes

## Helper script

This repo provides `scripts/agent-session` to automate the branch naming and create lightweight local snapshots under:

`~/.local/share/agent-logs/<repo>/<session-id>/`

### Usage

```bash
scripts/agent-session --topic "short description" --push
```

`--push` requires checkout mode (default). If you pass `--no-checkout`, push manually after selecting/creating the branch you want.

### Diff capture

By default the script stores diff *stats* only (`--diff stat`) to avoid large logs and reduce accidental leakage.

- `--diff none`: no diffs
- `--diff stat`: `git diff --stat` (default)
- `--diff full`: full patch snapshots (`git diff`, `git diff --cached`)
