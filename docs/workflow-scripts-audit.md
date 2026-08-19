# Workflow skills & scripts audit

The four orchestration skills (`agent-session`, `finish-session`, `new-project`, `sync-projects`)
and the shell scripts they drive. Never audited before. Several findings were verified empirically
rather than reasoned about.

This is the highest-stakes cluster in the repo: these scripts create branches, scaffold projects,
open and land PRs, and write symlinks into `$HOME`.

---

## Critical — can lose work or corrupt state

### 1. `sync-projects` reports success on every failed clone and pull

`scripts/sync-projects:82,152`

```bash
run git clone "${clone_url}" "${target}"
(( cloned++ )) || true
return
```

`sync_repo` is called at line 174 as `sync_repo "$line" || (( errors++ )) || true`. Because the
function runs in a `||` context, **bash disables `set -e` for its entire body**. A failed clone —
network down, private repo, bad slug — does not abort. Execution falls through to `(( cloned++ ))`
and returns 0. Same at line 152 for `git pull --ff-only`.

Verified: a synthetic `sync_repo` with a failing command prints `cloned=1 errors=0 exit=0`.

**Why this is the work-loss vector:** run `sync-projects` on the second machine, see
`cloned=6 updated=3 errors=0`, believe you're current, work on top of stale trees.

It also makes `skills/sync-projects/SKILL.md:46` ("Exit status is non-zero if any repo errored")
false.

```bash
if ! run git clone "${clone_url}" "${target}"; then
  echo "   ⚠ clone failed: ${slug}" >&2; return 1
fi
(( cloned++ )) || true
```

Never rely on `set -e` inside a function that is ever called in a conditional.

### 2. `finish-session` can auto-merge to `main` without CI

`scripts/finish-session:139` runs `gh pr merge "$BRANCH" --auto "$merge_flag" --delete-branch`
with no check that branch protection exists. `skills/finish-session/SKILL.md:23-25` asserts the
guardrail:

> "This relies on branch protection requiring the `scripts-check` check, so a red PR cannot merge."

On a repo without a required-check ruleset — which is most personal repos — `--auto` either errors
or merges as soon as it is mergeable, i.e. immediately, CI irrelevant. The skill tells the agent a
safety property that may not hold.

```bash
gh api "repos/{owner}/{repo}/branches/${BASE}/protection/required_status_checks" \
  --jq '.contexts[]' 2>/dev/null | grep -qx scripts-check \
  || die "no required 'scripts-check' on ${BASE}: --auto would merge without CI."
```

### 3. The default close-out always fails after a successful merge

`scripts/finish-session:161` — `run git branch -d "$BRANCH"`

Default `STRATEGY="squash"`. After a squash merge the branch's commits are not ancestors of
`main`, so `git branch -d` refuses. Verified: `error: the branch 'feat' is not fully merged.` → exit 1.

Under `set -e` the script dies there — *after* the PR merged and the remote branch was deleted —
never printing `Done.`. An agent reads non-zero as "the land failed" and may retry or improvise.

```bash
if ! run git branch -d "$BRANCH"; then
  warn "squash merge leaves ${BRANCH} unmerged by ancestry; PR is MERGED, deleting"
  run git branch -D "$BRANCH"
fi
```

### 4. `finish-session` never fetches

`scripts/finish-session:72-73` computes `ahead` against local `$BASE`. There is no `git fetch`
anywhere in the script. Stale local `main` → the PR body lists commits already on main. No local
`main` at all → `ahead=0` and it refuses to land real work with a wrong reason.

Both `agent-session`'s skill and CLAUDE.md:201-210 insist on fetching before branching. The
close-out skips it. Fetch `origin/$BASE` and compare against that.

### 5. `new-project` leaves an unrepeatable half-built project

`require_cmd gh` isn't reached until line 287 — after the directory, all rendered files, and the
initial commit exist. Missing `gh`, expired auth, or unset `user.email` aborts mid-way, and the
retry dies on `target already exists`. There's no cleanup and no `--force`.

Hoist every precondition above `mkdir`, and either `trap ... ERR` to clean up or print the exact
cleanup command.

### 6. Registry corruption, both directions

`scripts/new-project:304` — `echo "$SLUG" >> "$REGISTRY"` with no trailing-newline guard. If
`current-projects` doesn't end in a newline (likely now that a Windows editor may touch it), you
get `alexperreira/oldrepoalexperreira/newrepo` on one line.

`scripts/sync-projects:168` — `while IFS= read -r line; do` drops the last line when the file has
no trailing newline. Verified.

Together: one bad append makes **two** repos silently invisible to sync — and per finding 1, the
resulting garbage clone reports as a success.

```bash
# new-project
[[ -s "$REGISTRY" && -n "$(tail -c1 "$REGISTRY")" ]] && printf '\n' >> "$REGISTRY"
printf '%s\n' "$SLUG" >> "$REGISTRY"

# sync-projects
while IFS= read -r line || [[ -n "$line" ]]; do
```

### 7. The CI wait loop never times out and greps prose

`scripts/finish-session:148-156` — `gh pr checks "$BRANCH" | grep -qiE '\bfail'`

Matches any check *named* something containing "fail" (`test-failure-modes`), and matches a failing
**non-required** check that auto-merge would merge past — either way it aborts a healthy land. And
`while true; ... sleep 10` blocks the session forever if CI queues or a reviewer never appears.

Use `gh pr checks --required --json state --jq '.[].state' | grep -qx FAILURE`, and bound the wait
with a `--timeout` flag.

### 8. A merged or closed PR is treated as reusable

`scripts/finish-session:117` — `gh pr view` succeeds for MERGED and CLOSED PRs. Re-running on a
branch whose earlier PR merged prints "PR already exists", skips creation, then fails on merge.
The new commits are never proposed. Check `--json state --jq .state == "OPEN"`.

---

## Broken by the move to `/mnt/c`

### 9. `~/scripts/check` and `~/scripts/bootstrap-home-links` resolve `REPO_ROOT` to `$HOME`

`scripts/check:5`, `scripts/bootstrap-home-links:55`

```bash
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
```

Bash's `cd`/`pwd` builtins resolve `..` **logically**. `~/scripts` is now an ext4 symlink into
`/mnt/c/.../agent-scripts/scripts`, so `${SCRIPT_DIR}/..` is the parent of the *symlink* —
`$HOME` — not the repo.

Verified: `/tmp/t2/slink -> /tmp/t2/real/scripts` gives `REPO_ROOT=/tmp/t2`.

Every documented invocation hits this (CLAUDE.md:264-269 tells you to run `~/scripts/check`).

**`bootstrap-home-links` is the severe case.** With `REPO_ROOT="$HOME"`, each link pair becomes
`~/CLAUDE.md → ~/CLAUDE.md`. `link_one` resolves both sides, finds them identical, prints
`ok:`, and returns. **The script whose entire job is verifying the links is a tautology that can
never detect a broken one.** On a fresh machine it's worse: it dies with
`missing /home/alexa/CLAUDE.md` — the very path it exists to create.

```bash
SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -P -- "${SCRIPT_DIR}/.." && pwd -P)"
[[ "$REPO_ROOT" != "$HOME" ]] || die "refusing to link \$HOME to itself"
```

`new-project:256` and `sync-projects:23` are *not* affected — they pass `${SCRIPT_DIR}/../templates`
to the kernel, which resolves `..` physically. Only the bash builtins are wrong.

Same root cause: `bootstrap-home-links:167` prints `/plugin marketplace add /home/alexa`.

### 10. CRLF makes `check` lie in both directions

`scripts/check:160` — `[[ "$(head -n 1 "$skill")" == "---" ]]`

A Windows-side edit gives `---\r`; the check reports "missing frontmatter" when it's present.
Line 167 reports `frontmatter name 'agent-session' != directory 'agent-session'` — an error that
reads as impossible.

Worse and undetected: a CRLF shebang (`#!/usr/bin/env bash\r`) makes every script unrunnable
(`bad interpreter: ^M`) while `check:53`'s discovery regex `'^#!.*bash'` still matches — so
**`check` reports success on a completely broken tree.**

```
# .gitattributes
* text=auto eol=lf
scripts/** text eol=lf
```

plus `git config core.autocrlf false` and an explicit gate in `check`:
`! grep -rlqU $'\r$' scripts skills || die "CRLF line endings found"`

### 11. The executability gate is now meaningless

`scripts/check:74` — `[[ -x "$file" ]]`

Without `metadata` in `/etc/wsl.conf`, `/mnt/c` reports a uniform mode for every file, so `-x`
passes unconditionally. Meanwhile `core.fileMode false` means git now ignores real chmods — so if
a script's **index** mode regresses to `100644`, a fresh clone on a POSIX filesystem gets a
non-executable `agent-session` and `check` won't notice.

```bash
bad="$(git -C "$REPO_ROOT" ls-files --stage -- scripts | awk '$1!="100755" && $4!~"/lib/" {print $4}')"
[[ -z "$bad" ]] || die "not executable in git index: ${bad}"
```

### 12. Every new project is seeded with advice contradicting the move

`scripts/new-project:159`

```
- Prefer keeping the repo on the WSL filesystem (not under `/mnt/c`) for performance.
```

This lands in the generated `CLAUDE.md` of every project created from now on — including projects
created *into* `/mnt/c/Users/alexa/Projects`. A future agent will propose relocating the repo off
the drive Cowork can see.

Replace with the real trade-off (see the ADR).

### 13. Both scripts still default to `~/Projects` on ext4

`scripts/new-project:169`, `scripts/sync-projects:22` — `PROJECTS_DIR="${HOME}/Projects"`

Unless `~/Projects` is itself a symlink (documented nowhere), `new-project` scaffolds where Cowork
can't see, and `sync-projects` clones a **second copy of every repo** there — two divergent working
trees per project, both reporting clean.

`PROJECTS_DIR="${AGENT_SCRIPTS_PROJECTS_DIR:-/mnt/c/Users/alexa/Projects}"`

### 14. New repos on `/mnt/c` will repeat the 33-file mode incident

`scripts/new-project:279-284` — `git init -b main` then `git add -A`, with no `core.fileMode`
config. Add `case "$TARGET_DIR" in /mnt/*) git config core.fileMode false ;; esac` after init.

### 15. Smaller ones

- **`scripts/agent-session:103`** — `REPO_DIR="$(cd "$REPO_DIR" && pwd)"` records the symlinked
  path in the session snapshot, so the breadcrumb doesn't identify the real tree. Also `cd` without
  `||` — a bad `--repo` exits 1 silently. Use `cd -P ... && pwd -P` with a `die`.
- **No stale-lock handling** in `sync-projects` or `finish-session`. Since git through the Cowork
  bridge can leave `.git/index.lock` behind, the next sync fails on that repo — swallowed by
  finding 1. Skip and warn on a pre-existing lock.
- **Case-insensitivity**: `sync-projects:73` derives the target dir from `${slug##*/}`. Two registry
  entries differing only in case resolve to two directories on ext4 but **collide on `/mnt/c`** —
  the second clone finds an existing repo with the wrong origin and pulls into it.

---

## Skill vs script mismatches

| Skill claim | Reality |
|---|---|
| `sync-projects:46` "Exit status is non-zero if any repo errored" | Flatly false — see finding 1 |
| `sync-projects:20-24` `--dry-run` previews | Script skips the fetch in dry-run (line 111), so it reports "up to date" for repos that are behind |
| `sync-projects:38-43` skip list | Omits "fetch failed" (script line 112-116) |
| `finish-session:20-21` "clean tree" | Tracked diffs only; untracked files pass |
| `finish-session:33-45` usage | Omits `--draft`, the one mode for work that isn't ready |
| `finish-session:52` "never deletes an unmerged branch" | Will stop being true once finding 3 is fixed |
| `agent-session:19-21` "Run `git fetch origin` before branching" | The script has no fetch and no base check — it branches from whatever HEAD is, including a **previous agent branch**, silently stacking features |
| `agent-session:39-41` snapshot list | Omits `remotes.txt` |
| `new-project:31` "Always dry-run first" | Dry-run exits before every validation, so it can't fail — a preview that means nothing |
| `new-project:51-55` keyword list | Narrower than the script; `should_include_python_section` substring-matches `py`/`uv`, so `numpy` or `uvicorn` silently appends a Python quickstart to a Node project |

The `agent-session` fetch gap is the one to fix in the **script**, not the skill — a warning the
model is told to honor gets skipped whenever it's in a hurry.

---

## Violates the repo's own CLAUDE.md

- **`finish-session` skill authorizes an unapproved merge to `main`.** Its proactive trigger
  ("Also trigger proactively when a branch's work is done…") conflicts with CLAUDE.md:64-67, which
  requires a checkbox plan and explicit approval for "git actions beyond read-only inspection."
  Combined with finding 2, a proactive trigger can be an immediate merge.
- **`new-project:282` `git add -A`** vs CLAUDE.md:151-152 ("stage only files you changed… list each
  path explicitly"). Defensible for an init commit, but it's the one place the repo breaks its own
  rule silently.
- **`new-project:304` dirties a tracked file and never commits it.** `current-projects` is tracked,
  CLAUDE.md:147 forbids committing it unattended, and `sync-projects:104` then skips `agent-scripts`
  on every subsequent run with "has uncommitted changes". **The orchestration repo silently stops
  syncing itself.**
- **`check:97` `trap 'rm -rf "$FS_TMP"' EXIT`** vs CLAUDE.md:124's unqualified `rm` prohibition.
  The rule is aimed at agents, not at scripts cleaning their own `mktemp -d` — but as written, any
  agent auditing this repo will flag it. Add the exemption to CLAUDE.md.
- **CLAUDE.md:180-185** documents step 5 as `git branch -d`, which always fails on squash (finding 3).
- **CLAUDE.md:22 vs :25-27** — `/mnt/c/Users/alexa/Projects` matches "external mounts → ask before
  accessing" and doesn't match `~/Projects`. A rule-following agent will stop and ask before reading
  his own code.
- **CLAUDE.md:238** — "Prefer working in a dedicated projects directory inside WSL" is now false.
- **`check:83`** hardcodes `setup-claude-mcps`, which isn't in `scripts/`, contradicting the file's
  own "scripts are discovered by shebang" design. If genuinely missing, `check` fails with a message
  that gives no hint the file doesn't exist.
- **`check` never exercises `bootstrap-home-links` beyond `--help`** — the highest-blast-radius
  script in the repo, and the one broken by the move.

---

## Document quality

Only four items; these files are already tight.

- `new-project:70` "Do not `cd` into the new repo and start work unless asked" → "Stop after
  reporting. Wait for the user to say what to build."
- `agent-session:27-31` duplicates CLAUDE.md:194-197 verbatim — two copies to keep in sync by hand.
  Replace with a pointer.
- `finish-session:15-16` restates the frontmatter ("the counterpart to `agent-session`"). Delete.
- **`finish-session` has no "After it runs" section** — the one skill ending in an irreversible
  merge is the only one that doesn't say what to report. Add: report the PR URL, the merge commit
  SHA, confirm branch deletion; if the wait timed out say so explicitly rather than reporting it
  as landed.

Frontmatter descriptions: 389 / 489 / 397 / 330 chars. All comfortable.

---

## What's genuinely good — keep

- **`lib/common.sh:16-22` `require_arg_value` rejecting values starting with `--`.** Kills the
  classic `--owner --dry-run` argument swallow, and `check` tests it for five flags. Better than
  most production shell.
- **`new-project:46-51` `escape_sed_replacement`** — escapes `\`, `&`, `/` in the correct order.
  The single most commonly botched thing in template-rendering shell, and it's right.
- **`check:133-137` the un-replaced `{{TOKEN}}` scan**, run against rendered output rather than the
  template. Exactly the right place.
- **`sync-projects:127-160` merge-base classification** — ahead / fast-forwardable / diverged is
  textbook-correct and conservative in the right direction. Only the error handling around it is broken.
- **`bootstrap-home-links:64-105` `link_one`** refuses to clobber a real file and resolves both
  sides with `readlink -f` before comparing, with a comment explaining why. That comment is the
  reason it survives being run through a symlinked `~/scripts` without corrupting anything.
- **`finish-session:110-114`** never force-pushes, and `--pretty=format:'- %s'` at line 85 means
  commit trailers can't leak into the PR body — satisfying the no-AI-attribution rule *by
  construction* rather than by discipline.
- **`check:52-58 + 153-173`** — shebang-based discovery plus the `name` == directory assertion,
  which catches a rename that would otherwise silently un-register a skill.

---

## Suggested order

1. **Finding 1** (sync reports false success) — silent, ongoing, and the only one that can cost work.
2. **Finding 9** (`REPO_ROOT` → `$HOME`) — `bootstrap-home-links` currently validates nothing.
3. **Findings 3 + 2** (`branch -d` always fails; auto-merge without CI) — every land is affected.
4. **Finding 10** (`.gitattributes`) — one file, prevents a whole class of confusing failure.
5. **Findings 12 + 13** (paths and seeded advice) — otherwise every new project inherits the wrong
   layout.
6. Everything else.

Items 1–4 are roughly an hour and remove all the silent-failure modes.
