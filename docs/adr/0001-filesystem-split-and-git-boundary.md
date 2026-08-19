# ADR-0001: Filesystem split between WSL2 and Windows, and where git runs

**Status:** Accepted — 2026-08-18
**Task doc:** none (arose from a workflow migration)

## Context

Cowork's device bridge mounts folders the desktop app can see. Its folder picker cannot navigate
to `\\wsl.localhost\<distro>\...`, so nothing inside the WSL2 ext4 filesystem was reachable —
verified by attempting it. Working interchangeably between Cowork and Claude Code required at least
some files to live on the Windows drive.

Moving everything is not free. `/mnt/c` is DrvFs/Plan 9 (virtiofs remains opt-in as of the May 2026
kernel). Many-small-file work is slow, inotify does not fire for Windows-side writes, and the
`cp` from ext4 flipped all 33 tracked files from `100644` to `100755`.

Separately, git operations **through the Cowork bridge** fail: the mount forbids `unlink()`, so git
cannot remove `index.lock`, `next-index-N.lock`, or `tmp_obj_*`. It writes objects and then aborts,
leaving debris. This is a property of the bridge, not of `/mnt/c` — git run from the WSL2 shell
against the same directory works fine.

## Decision

**Split by workload, not by tool.**

| Lives on | What | Why |
|---|---|---|
| `/mnt/c/Users/alexa/Projects/` | `agent-scripts`, docs, anything Cowork edits | Small text files; DrvFs cost is invisible; Cowork can reach it |
| WSL2 ext4 (`~/...`) | Expo/RN projects, anything with `node_modules`, a bundler, or a file watcher | DrvFs cost is severe and inotify breakage is silent |
| WSL2 ext4 | `~/.claude`, `~/.codex`, agent logs | Read by tools running in WSL2; Cowork never reads them |

**Symlinks point one direction only:** the link lives on ext4, the target on `/mnt/c`. Links stored
on `/mnt/c` are unreliable.

**Git runs from the WSL2 shell — never through the Cowork bridge.** Cowork edits files; a human or
Claude Code commits them.

`core.fileMode false` is set on any repo living under `/mnt/c`.

## Alternatives considered

| Option | Why not |
|---|---|
| Everything on `/mnt/c` | Expo builds and Metro watch mode degrade badly; inotify failures are silent, which is worse than slow |
| Everything on ext4, Cowork reaches in via `\\wsl.localhost` | The folder picker rejects UNC paths — tested, does not work |
| Enable `virtiofs=true` and move everything | Narrows the performance gap but does not close it, does not fix inotify, and does not fix the bridge's `unlink` restriction |
| Keep two copies and sync | Two working trees per project, both reporting clean; the failure mode is silent divergence |

## Consequences

**Positive**

- Cowork and Claude Code operate on the same files with no copy step.
- Build-sensitive work keeps ext4 performance.
- The git boundary is explicit, so bridge write failures stop being mysterious.

**Negative**

- Two locations to remember; new projects must be placed deliberately.
- `core.fileMode false` means real permission changes are no longer tracked — a script whose index
  mode regresses to `100644` will not be caught by a working-tree check.
- Windows-side edits do not trigger inotify, so `/reload-plugins` can serve stale skill content.
  Edit skills from the WSL side, or restart the session.
- `agent-scripts` scripts that assumed `$HOME`-relative paths are wrong until fixed — see
  `docs/workflow-scripts-audit.md`, findings 9 and 13.

**Revisit if** the Cowork folder picker gains UNC support, or virtiofs becomes the WSL2 default and
closes the small-file gap.
