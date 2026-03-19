# PROPAGATE_ACTIVE_ARCHIVE_TASK_WORKFLOW.md
_Prepared by: CD | Date: March 2026_

---

## Overview

The canonical task doc workflow is: write to `docs/active/`, move to `docs/archive/` after completion. Three places in `agent-scripts` still reference the old `docs/tasks/` convention or fail to scaffold the directory structure. This task aligns everything.

| Field | Detail |
|---|---|
| **Scope** | `AGENTS.md` text update, `new-project` directory scaffolding, template update |
| **Risk** | Low — text/path changes only, no logic changes |
| **Stack** | Bash, Markdown |
| **Files affected** | `AGENTS.md` (~2 lines), `new-project` (~1 line), `templates/empty/AGENTS.md.tmpl` (if it references `docs/tasks/`) |
| **Depends on** | None |
| **Blocks** | Nothing — but should land before next `new-project` run so new repos get the right structure |

---

## Context

Alex's workflow for task documents has evolved:
- **Active work:** task docs live in `docs/active/`
- **Completed work:** task docs (or summarized versions) move to `docs/archive/`

The repo still references the old `docs/tasks/` convention in `AGENTS.md`, and `new-project` only scaffolds `docs/` without creating either subdirectory. New projects start without the correct directory structure, and any agent reading `AGENTS.md` will use the stale `docs/tasks/` path.

---

## Goal

After this change:
1. `AGENTS.md` references `docs/active/` and `docs/archive/` instead of `docs/tasks/`
2. `new-project` creates both `docs/active/` and `docs/archive/` in every new repo
3. The AGENTS.md template for new projects (`templates/empty/AGENTS.md.tmpl`) references the correct paths so downstream repos inherit the convention

---

## Tasks

### Task 1 — Update `AGENTS.md` task file path references

**File:** `AGENTS.md`, Planning & Task Decomposition section

Find the line (approximately):

```
Create a task file per logical feature branch in `docs/tasks/` (or `/tmp/tasks/`
for ephemeral work), named `<YYYYMMDD>-<feature-slug>.md`.
```

Replace with:

```
Create a task file per logical feature branch in `docs/active/` (or `/tmp/tasks/`
for ephemeral work), named `<YYYYMMDD>-<feature-slug>.md`. Move completed task
docs (or a summarized version) to `docs/archive/`.
```

Scan the rest of `AGENTS.md` for any other occurrences of `docs/tasks/`. Replace each with `docs/active/` as appropriate.

> **Footgun:** `AGENTS.md` is symlinked to `~/AGENTS.md` and `~/CLAUDE.md` via `bootstrap-home-links`. The symlinks point to the file, not a copy — so editing the source file is sufficient. Do not create separate copies.

---

### Task 2 — Scaffold `docs/active/` and `docs/archive/` in `new-project`

**File:** `new-project`, around line 223

The current line:

```bash
mkdir -p "${TARGET_DIR}/docs"
```

Replace with:

```bash
mkdir -p "${TARGET_DIR}/docs/active" "${TARGET_DIR}/docs/archive"
```

`mkdir -p` creates the parent `docs/` implicitly, so no separate call needed.

**Git empty directory handling:** Git doesn't track empty directories. Add a `.gitkeep` in each so the structure survives the initial commit:

```bash
touch "${TARGET_DIR}/docs/active/.gitkeep"
touch "${TARGET_DIR}/docs/archive/.gitkeep"
```

Insert these two lines immediately after the `mkdir -p` call.

---

### Task 3 — Update `templates/empty/AGENTS.md.tmpl`

**File:** `templates/empty/AGENTS.md.tmpl`

Check whether this template references `docs/tasks/`. If it does, update it to match the same language from Task 1 (`docs/active/`, with the archive note). If the template doesn't mention task file paths, no change needed — just confirm and move on.

> **Footgun:** The template uses `{{VAR}}` tokens. The text being changed here is plain prose, not token values, so no escaping concerns. But verify you're editing the `.tmpl` file, not the rendered `AGENTS.md` in a generated project.

---

## Out of Scope

- **Do not modify the task-doc-generator skill.** That's a Claude-side skill, not a repo file. Its footer text (`Archive to: docs/archive/...`) is already correct. The missing `docs/active/` initial-path callout in the skill is a separate skill-edit concern.
- **Do not retrofit existing projects.** This only affects new repos going forward. Existing repos can add the directories manually or via a one-liner.
- **Do not modify `agent-session`, `sync-projects`, `bootstrap-home-links`, `check`, or `setup-claude-mcps`.**
- **Do not rename or restructure `templates/empty/`.**
- **Do not add new CLI flags.**

---

## Acceptance Criteria

- [ ] `AGENTS.md` contains `docs/active/` where it previously said `docs/tasks/`
- [ ] `AGENTS.md` mentions the `docs/archive/` move-on-completion convention
- [ ] `AGENTS.md` contains zero remaining references to `docs/tasks/`
- [ ] `scripts/new-project --name test-proj --no-remote --projects-dir /tmp` creates `docs/active/` and `docs/archive/` with `.gitkeep` files in each
- [ ] The initial commit in a new project includes both directories
- [ ] `templates/empty/AGENTS.md.tmpl` references `docs/active/` (if it previously referenced `docs/tasks/`)
- [ ] `scripts/check` still passes
- [ ] Existing scripts (`agent-session`, `sync-projects`, etc.) are unchanged

---

_Pass this document directly to CC. All tasks are self-contained and executable sequentially._
_Archive to: docs/archive/PROPAGATE_ACTIVE_ARCHIVE_TASK_WORKFLOW.md after completion._