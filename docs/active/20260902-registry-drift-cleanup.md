# Feature: reconcile `current-projects` with what is actually on disk

**Goal:** Make `current-projects` an accurate index of every repo on this machine, and remove the
duplicate/empty directories that made it inaccurate, without losing unpushed work.

**Depends on:** none. (Follows PR #17, which fixed the docs; this fixes the data.)

## Context

Surveyed 2026-09-02 across both roots defined in ADR-0001. The registry lists 16 slugs; the disk
holds 20 directories. Almost none of the mismatch is benign — it includes a second cross-filesystem
duplicate of the same kind that produced the `wodgenerator` divergence in PR #17.

`sync-projects` derives its target directory from the slug (`scripts/sync-projects:81-82`,
`repo_name="${slug##*/}"`). So **registering a repo whose local directory is named differently
clones a second copy** rather than adopting the existing one. Two entries below are in exactly that
state, which is why this is a task doc and not a one-line append.

### Current state

**Listed but cloned nowhere** — all three exist on GitHub and are live:

| Slug | Visibility | Last push |
|---|---|---|
| `alexperreira/chat-migrator` | private | 2026-03-13 |
| `alexperreira/scripts-showcase` | private | 2026-03-19 |
| `alexperreira/dep-sentry` | public | 2026-03-25 |

**Cloned but unlisted:**

| Directory | Root | Remote | State |
|---|---|---|---|
| `Obs-sync` | ext4 | `obsidian-git-sync` | **dir name ≠ repo name**; 1 dirty file |
| `ai-girlfriend` | ext4 | `ai-girlfriend` | clean |
| `root-portfolio` | ext4 | `root-portfolio` | clean |
| `lanradar` | `/mnt/c` | `lanradar` | 14 dirty files |
| `walaau` | `/mnt/c` | `walaau` | clean |

**Actively wrong:**

| Directory | Root | Problem |
|---|---|---|
| `FileParser` | `/mnt/c` | Clone of **`alexperreira/parsnip`** under a different name — duplicates `~/Projects/parsnip`. Stale (`85ff11c`, 2026-02-07) vs ext4 (`e1c9ec5`, 2026-03-04). Second instance of the PR #17 failure mode. |
| `ai-automator` | `/mnt/c` | Empty directory, 0 bytes, no git, no GitHub repo. |
| `ai-curriculum` | ext4 | Real content (`CURRICULUM-PLAN.md`, `courses/`) but no git repo and no remote. Unbacked. |
| `node_modules/`, `package.json`, `pnpm-lock.yaml` | ext4 | Stray `npm install` at the Projects root. `package.json` is literally `{}`; `node_modules` is 8K. |

**Unpushed work — handle before anything else:**

- `/mnt/c/uluhe` — **10 unpushed commits** (`08b4cd2`…`7d6a3ac`, n8n email-triage work). `uluhe` is
  also the slug sitting uncommitted in `current-projects` on `main`.
- `lanradar` — 14 uncommitted files.
- `Obs-sync` — 1 uncommitted file (`obsidian_git_sync.py`).

## Steps

### Phase 1 — preserve work (blocks everything else)

- [x] Step A — **done.** The 10 commits were on an unpushed feature branch
      (`docs/phase3-outreach-and-mail-dns`) with no upstream, not on `main`. Pushed with `-u`;
      `git log --branches --not --remotes` now returns 0.
- [x] Step B — **done, still open for Alex.** `lanradar` has 14 uncommitted files and
      `obsidian-git-sync` has 1 (`obsidian_git_sync.py`). Left untouched.
- [x] Step C — **done.** Verified accurate first: `uluhe` is on `/mnt/c` and the dry-run reports it
      already up to date, so the line describes reality.

### Phase 2 — resolve duplicates and empties (needs explicit approval per CLAUDE.md guardrails)

- [x] Step D — **done.** `FileParser` had 0 unpushed, 0 dirty, 0 stashes, only `main`, and **no
      `.env`-class files**. Trashed to `/mnt/c/.Trash-1000/files/FileParser`. `parsnip` was already
      at `e1c9ec5`, ahead of the copy removed.
- [x] Step E — **done.** Confirmed 0 files / 0 bytes, then trashed.
- [x] Step F — **done.** All four were empty install artifacts (`package.json` = `{}`, lockfiles
      with no importers, `node_modules` holding only a pnpm state file). Trashed, incl.
      `package-lock.json`, which the original survey missed.
- [x] Step G — **decided: leave unmanaged.** Still unbacked by any remote; that is now a known,
      accepted state rather than an oversight.

### Phase 3 — BLOCKED: the registry cannot express ADR-0001

Running `sync-projects --dry-run` before touching the registry surfaced a structural conflict that
invalidates Steps H–K as originally written.

**The registry is a flat list of slugs resolved against a single `PROJECTS_DIR`**
(`scripts/sync-projects:81-82`). ADR-0001 requires **two** roots. There is no way to say "this repo
lives on ext4" — so every ext4 repo listed in `current-projects` is a landmine: running
`sync-projects` clones a second copy into `/mnt/c`, which is exactly the divergence that produced
`wodgenerator` (PR #17) and `FileParser` (Step D).

This is **pre-existing, not caused by this task.** The first dry-run reported `cloned=14` — 11 of
those already existed on ext4. Appending the unlisted ext4 repos as Step H proposed would have taken
it to 17. After Step J's clones it stands at **12 phantom clones**: `app-policy-auditor`,
`blog-automater`, `chat-migrator`, `clarity-pm`, `code-autopsy`, `cyber-blog`, `ghost-shell`,
`mrclean`, `nexgensec`, `packet-punk`, `parsnip`, `wodgenerator`.

- [x] Step I — **done.** `Obs-sync` renamed to `obsidian-git-sync` to match its remote. The dirty
      file was preserved. This had to precede any registry append, or `sync-projects` would have
      cloned a duplicate alongside it.
- [x] Step J — **done, placed by ADR-0001 rather than by the registry's default:**
      - `scripts-showcase` (docs only, 1KB) → `/mnt/c`, `core.fileMode false`
      - `dep-sentry` (Python, `pyproject.toml`, no watcher) → `/mnt/c`, `core.fileMode false`
      - `chat-migrator` (**Vite + Tailwind + pnpm**) → **ext4**, because Vite HMR depends on inotify,
        which does not fire for Windows-side writes. Registered, so `sync-projects` will try to clone
        it to `/mnt/c` — one of the 12 above.
- [ ] Step H — **blocked.** Do not append `ai-girlfriend`, `root-portfolio`, `obsidian-git-sync`,
      `lanradar`, or `walaau` until placement is expressible. `lanradar` and `walaau` are on `/mnt/c`
      and would be safe today, but adding only those bakes in the inconsistency.
- [ ] Step K — **blocked on the same decision.**

### Phase 3a — resolve the placement conflict (needs Alex's decision)

Three ways out, in the order I would pick them:

1. **Add a placement column** — `owner/repo[<TAB>root]`, defaulting to `/mnt/c`. `sync-projects`
    reads it and clones ext4 repos to `$HOME/Projects`. Registry stays one file, ADR-0001 holds, the
    dry-run can reach zero. Costs a parser change plus a migration of the 12 rows.
2. **Two registries** — `current-projects` and `current-projects-ext4`, with `sync-projects --root`
    selecting. Simpler to implement, easy to let drift apart.
3. **Register only `/mnt/c` repos** and document that ext4 repos are deliberately unmanaged. Zero
    code change, but the registry stops being the machine's index — which is what it is for.

## Phase 4 — verify

- [ ] Step L — acceptance test, **revised**: `sync-projects --dry-run` reporting `cloned=0`. This is
      unreachable until Phase 3a lands. The original doc asserted it as achievable; it never was.
- [x] Step M — `scripts/check` passes.

## Parallel-safe notes

- Phase 1 gated Phase 2 for `uluhe` only; D/E/F touched unrelated paths and ran concurrently.
- Phase 3 is strictly sequential — every step edits `current-projects`.
- Step I's rename had to precede its registry append, or the duplicate it prevents is created.
- Phase 3a is a prerequisite for the rest of Phase 3, not a parallel track.

## Risks

- **`gio trash` is the delete mechanism, never `rm`.** `trash-put` is not installed on this machine
  (`apt-get install trash-cli` would fix that). `gio trash` on `/mnt/c` lands in
  `/mnt/c/.Trash-1000/files/` — same filesystem, so it is an instant rename and fully recoverable.
- **Untracked `.env` files do not show in any git status check.** The `wodgenerator` cleanup nearly
  destroyed live config that existed on no remote. Every Phase 2 deletion must check for
  `.env`-class files first and compare against the surviving copy.
- Adding a slug whose local directory has a different name silently creates a second working tree.
  This is the `Obs-sync` case and the cause of the `FileParser` mess.

## Outputs

**Delivered**

- Pushed: `uluhe` branch `docs/phase3-outreach-and-mail-dns` (10 commits)
- Trashed (recoverable): `/mnt/c/FileParser`, `/mnt/c/ai-automator`,
  `~/Projects/{node_modules,package.json,package-lock.json,pnpm-lock.yaml}`
- Renamed: `~/Projects/Obs-sync` → `~/Projects/obsidian-git-sync`
- Cloned: `scripts-showcase`, `dep-sentry` (`/mnt/c`); `chat-migrator` (ext4)
- `current-projects` — `uluhe` line committed
- Phantom clones in `sync-projects --dry-run`: 14 → 12

**Still open**

- Phase 3a decision, then Steps H and K
- `lanradar` (14 dirty files) and `obsidian-git-sync` (1) — Alex's uncommitted work
- `ai-curriculum` remains unbacked by choice
- `docs/archive/20260902-registry-drift-cleanup.md` — move this doc on completion
