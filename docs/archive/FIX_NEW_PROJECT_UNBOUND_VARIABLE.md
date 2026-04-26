# FIX_NEW_PROJECT_UNBOUND_VARIABLE.md
_Prepared by: CD | Date: April 2026_

---

## Overview

`scripts/new-project` crashes with `agents_path: unbound variable` at line 117 when run without a `--stack` flag. The script uses `set -euo pipefail` (the `u` flag treats unbound variables as errors), and somewhere in `append_stack_sections()` a variable reference triggers this. The fix is to make the function defensive against unbound parameters and confirm the repo copy matches what's installed via symlink.

| Field | Detail |
|---|---|
| **Scope** | `scripts/new-project` only — single function fix + smoke test |
| **Risk** | Low — isolated bug in a single function, no downstream consumers |
| **Stack** | Bash (shellcheck-clean, `set -euo pipefail`) |
| **Files affected** | `scripts/new-project`, `scripts/check` |
| **Depends on** | Nothing |
| **Blocks** | Any new project creation (the script is broken) |

---

## Context

Running `~/scripts/new-project --name Readaloud` (no `--stack` flag) produces:

```
/home/alex/scripts/new-project: line 117: agents_path: unbound variable
```

The error occurs inside `append_stack_sections()`. Under `set -u`, `local agents_path="$1"` will fail if `$1` is unset. The call site at line 232 does pass an argument (`"${TARGET_DIR}/AGENTS.md"`), so either:

1. The locally-installed script (via `~/scripts` symlink) diverges from the repo version, **or**
2. A bash version difference causes `local var="$1"` to evaluate `$1` before the local declaration is in scope.

Both cases are resolved by the same defensive fix: `local agents_path="${1:-}"` with an explicit guard.

---

## Problem / Goal

`scripts/new-project` is unusable — it crashes before creating the project directory when `--stack` is omitted (the most common invocation).

---

## Diagnosis

> **Root cause:** Script layer — `append_stack_sections()` in `scripts/new-project` (line ~91) uses `local agents_path="$1"` which, under `set -u`, is fragile to unset positional parameters depending on bash version behavior. The function parameter `$1` should be captured with `${1:-}` and explicitly validated.

---

## Tasks

### Task 0 — Diagnostic: Confirm symlink is current

**Goal:** Verify the installed script matches the repo copy before patching.

**Steps:**
1. Check the symlink target:
   ```bash
   readlink -f ~/scripts/new-project
   ```
   Expected: `~/Projects/agent-scripts/scripts/new-project`

2. Diff the installed vs repo version:
   ```bash
   diff "$(readlink -f ~/scripts/new-project)" ~/Projects/agent-scripts/scripts/new-project
   ```
   - **If empty diff →** files match, proceed to Task 1.
   - **If non-empty diff →** the symlink is stale. Run `~/scripts/bootstrap-home-links --apply` first, then re-test. If the error persists, proceed to Task 1.

---

### Task 1 — Fix `append_stack_sections()` parameter handling

**File:** `scripts/new-project` — function `append_stack_sections()` around line 90

Replace the function's parameter capture with a defensive pattern:

```bash
# BEFORE (line 90-91):
append_stack_sections() {
  local agents_path="$1"

# AFTER:
append_stack_sections() {
  local agents_path="${1:-}"
  [[ -n "$agents_path" ]] || die "append_stack_sections: missing path argument"
```

This is the only change to this function. Do not modify the heredoc body or the call site at line 232.

---

### Task 2 — Apply the same pattern to `render_template()`

**File:** `scripts/new-project` — function `render_template()` around line 52

The same fragility exists here. Apply the same defensive pattern:

```bash
# BEFORE (lines 53-54):
render_template() {
  local template_path="$1"
  local output_path="$2"

# AFTER:
render_template() {
  local template_path="${1:-}"
  local output_path="${2:-}"
  [[ -n "$template_path" ]] || die "render_template: missing template path"
  [[ -n "$output_path" ]]   || die "render_template: missing output path"
```

---

### Task 3 — Add smoke test to `scripts/check`

**File:** `scripts/check` — add a new test block after the existing "Argument guard smoke checks" section (around line 40).

```bash
echo "==> new-project dry-run smoke check (no --stack)"
"${SCRIPT_DIR}/new-project" --name smoke-test-project --no-remote --dry-run >/dev/null
```

This exercises the code path that triggered the bug: `--name` provided, no `--stack`, which means `TECH_STACK=""` and `append_stack_sections` runs with neither node nor python sections.

⚠️ **Footgun:** Do not use `--dry-run` without `--no-remote` — the script prints remote info that references `gh` and would fail if `gh` is not installed. The `--dry-run` flag exits before any file writes or git operations, so this is safe.

---

## Out of Scope

- Do not modify `agent-session`, `bootstrap-home-links`, `sync-projects`, or `setup-claude-mcps`
- Do not refactor the heredoc structure inside `append_stack_sections()`
- Do not change the behavior of `should_include_node_section` or `should_include_python_section`
- Do not install new packages or dependencies
- Do not modify templates in `templates/`
- Do not touch `.env` or `~/.secrets`

---

## Acceptance Criteria

- [ ] `scripts/new-project --name test-project --no-remote --dry-run` completes without error (no `--stack`)
- [ ] `scripts/new-project --name test-project --stack "typescript, node" --no-remote --dry-run` still works
- [ ] `scripts/check` passes (including the new smoke test)
- [ ] `scripts/check --require-shellcheck` passes (if shellcheck is installed)
- [ ] `bash -n scripts/new-project` passes (syntax check)
- [ ] No unrelated files modified

---

_Pass this document directly to CC. All tasks are self-contained and executable sequentially._
_Archive to: docs/archive/FIX_NEW_PROJECT_UNBOUND_VARIABLE.md after completion._