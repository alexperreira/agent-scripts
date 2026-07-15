# Finishing a session (PR → land → cleanup)

`scripts/finish-session` is the counterpart to `agent-session`: it takes a
pushed agent branch and drives the "Standard PR flow" to completion.

## Usage

```bash
scripts/finish-session            # push → PR → merge-when-green → wait → delete
scripts/finish-session --no-wait  # enable auto-merge and return
scripts/finish-session --dry-run  # print the plan, do nothing
```

## Behavior

- Aborts unless you're on a feature branch with a clean tree and commits ahead
  of the base (`main`).
- Opens a PR if none exists (title from the branch topic, body from commits).
- Enables `gh pr merge --auto`, which only merges once the required
  `scripts-check` status check passes.
- Default waits for the merge and deletes the local branch; `--no-wait` skips
  the wait.

## Safety

Never force-pushes, never deletes an unmerged branch, no admin API calls. Relies
on branch protection on `main` requiring the `scripts-check` check.
