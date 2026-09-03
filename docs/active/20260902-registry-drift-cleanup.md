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

- [ ] Step A — push `uluhe`'s 10 commits, or confirm with Alex they should stay local. Sequential;
      nothing else touches `uluhe` until this resolves.
- [ ] Step B — report `lanradar`'s 14 dirty files and `Obs-sync`'s 1 dirty file to Alex. Do not
      commit or discard them; they are not this task's authorship. Parallel-safe with Step A.
- [ ] Step C — commit the pending `+alexperreira/uluhe` line already in the working tree on `main`.
      Needs Alex's word, since it is his edit. Sequential before Phase 3.

### Phase 2 — resolve duplicates and empties (needs explicit approval per CLAUDE.md guardrails)

- [ ] Step D — `FileParser`: confirm it holds nothing `parsnip` lacks (`git log --branches --not
      --remotes`, plus an untracked-file check for `.env`-class files — the `wodgenerator` cleanup
      showed git state alone is insufficient). Then `gio trash` it and fast-forward `~/Projects/parsnip`.
- [ ] Step E — `ai-automator`: verify still empty, then `gio trash`. Parallel-safe with D.
- [ ] Step F — stray `node_modules/`, `package.json`, `pnpm-lock.yaml` at `~/Projects` root:
      `gio trash`. Parallel-safe with D and E.
- [ ] Step G — `ai-curriculum`: decide with Alex — publish as a repo, fold into another, or leave
      unmanaged. **Leave on disk either way.** Parallel-safe.

### Phase 3 — reconcile the registry (sequential; single mutable file)

- [ ] Step H — decide per unlisted repo whether it should be tracked. `lanradar`, `walaau`,
      `ai-girlfriend`, `root-portfolio` are straightforward appends.
- [ ] Step I — `Obs-sync`: rename the directory to `obsidian-git-sync` **before** adding the slug,
      otherwise `sync-projects` clones a duplicate. Do the rename first, verify, then append.
- [ ] Step J — decide whether `chat-migrator`, `scripts-showcase`, `dep-sentry` should be cloned
      (`sync-projects` will place them in `/mnt/c` — check none is watcher/bundler-heavy first, per
      ADR-0001) or dropped from the registry.
- [ ] Step K — sort the registry and note the placement rule (`/mnt/c` default, ext4 for
      build-heavy) so the next reader knows why a listed repo may be absent from `/mnt/c`.

### Phase 4 — verify

- [ ] Step L — `~/scripts/sync-projects --dry-run` must report zero clones and zero warnings.
      This is the acceptance test: a clean dry-run means registry and disk agree.
- [ ] Step M — `scripts/check`.

## Parallel-safe notes

- Phase 1 gates Phase 2 for `uluhe` only; D/E/F touch unrelated paths and can run concurrently.
- Phase 3 is strictly sequential — every step edits `current-projects`.
- Step I's rename must precede its registry append, or the duplicate it prevents is created.

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

- `current-projects` — accurate, sorted, commented
- `docs/archive/20260902-registry-drift-cleanup.md` — this doc, on completion
- Removed: `/mnt/c/FileParser`, `/mnt/c/ai-automator`, `~/Projects/{node_modules,package.json,pnpm-lock.yaml}`
- Renamed: `~/Projects/Obs-sync` → `~/Projects/obsidian-git-sync`
