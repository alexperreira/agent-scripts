# ADD_MEASUREMENT_FRAMEWORK_TO_BOOTSTRAP.md
_Prepared by: CD | Date: March 2026_

---

## Overview

Add a project measurement framework template to the `new-project` bootstrap script so every new repo is created with a pre-filled `docs/MEASUREMENT.md`. The template auto-populates project name, stack, repo URL, and start date from CLI args — everything else stays blank for manual fill-in during development.

| Field | Detail |
|---|---|
| **Scope** | Template file + `new-project` render call + `check` smoke test. No changes to other scripts. |
| **Risk** | Low — additive only; existing template rendering is proven. |
| **Stack** | Bash, sed-based `{{VAR}}` templating (existing pattern) |
| **Files affected** | `templates/empty/MEASUREMENT.md.tmpl`, `new-project` (~3 lines), `check` (~5 lines) |
| **Depends on** | Existing `render_template()` function in `new-project` |
| **Blocks** | Nothing |

---

## Context

Alex maintains a project measurement framework document (resume bullets, architecture decisions, metrics, security posture, interview stories). Currently this is a standalone markdown file that must be manually copied into each project. Integrating it into `new-project` ensures every repo ships with the framework from day one, with key fields pre-populated so there's zero friction to start logging.

---

## Goal

After this change, running `scripts/new-project --name my-tool --stack "typescript, node, pnpm"` produces `docs/MEASUREMENT.md` in the new repo with:
- **Project Name** filled in (`my-tool`)
- **Stack** filled in (`typescript, node, pnpm`)
- **Repo URL** filled in (`https://github.com/alexperreira/my-tool`)
- **Start Date** filled in (today's date, `YYYY-MM-DD`)
- All other fields left blank (template placeholders)

---

## Tasks

### Task 1 — Add `{{DATE_TODAY}}` token to `render_template()`

**File:** `new-project`, inside `render_template()` (~line 47–76)

The existing token set doesn't include a full date — only `{{YEAR}}`. Add a `DATE_TODAY` variable and wire it into the sed expression array.

**1a — Define the variable** (alongside `YEAR` around line 162):

```bash
YEAR="$(date +%Y)"
DATE_TODAY="$(date +%Y-%m-%d)"
```

**1b — Add escape + sed line** inside `render_template()`:

```bash
local esc_date_today
esc_date_today="$(escape_sed_replacement "$DATE_TODAY")"

sed_expr+=("-e" "s/{{DATE_TODAY}}/${esc_date_today}/g")
```

Insert the `local` declaration with the other locals (~line 52–57), the escape call after the other escape calls (~line 59–64), and the sed line after the other sed lines (~line 67–73).

> **Footgun:** Keep the insertion positions consistent with existing pattern — locals block, then escapes block, then sed_expr block. Don't interleave.

---

### Task 2 — Create the template file

**File:** `templates/empty/MEASUREMENT.md.tmpl` (new file)

Create the template using `{{VAR}}` tokens for the four auto-filled fields. All other fields use empty placeholder values. The template content should match the structure of the measurement framework document provided below, with these substitutions:

| Section | Field | Template Value |
|---|---|---|
| Project Overview | Project Name | `{{PROJECT_NAME}}` |
| Project Overview | Stack | `{{TECH_STACK}}` |
| Project Overview | Repo URL | `https://github.com/{{GITHUB_OWNER}}/{{PROJECT_NAME}}` |
| Project Overview | Start Date | `{{DATE_TODAY}}` |
| Project Overview | Status | `Planning` (hardcoded — every new project starts here) |
| Header | Owner | `{{AUTHOR}}` |
| Header | Created | `{{DATE_TODAY}}` |
| Everything else | (all fields) | Empty / template placeholders as-is |

The full measurement framework structure (10 sections) should be preserved exactly:

1. Project Overview (table)
2. Architecture Decisions Log (repeatable template)
3. Problems Solved Log (repeatable template)
4. Technical Metrics (Performance, Scale, Code Quality tables)
5. Security Documentation (Auth, Controls, Testing, Threat Model)
6. CI/CD & DevOps (table)
7. Resume Bullet Drafts (blank bullets)
8. Interview Story Bank (STAR templates)
9. Weekly Update Log
10. Post-Project Retrospective

> **Footgun:** The template contains markdown table pipes (`|`) and backticks. `sed` replacement is safe here because the _tokens_ being replaced (`{{PROJECT_NAME}}` etc.) don't appear inside table cells that also contain pipes. But verify the rendered output doesn't mangle any table rows — Task 4 (smoke test) covers this.

> **Footgun:** The template also contains `{{` and `}}` in the Architecture Decisions Log and Problems Solved Log as literal placeholder syntax (e.g., `[DATE] — [Decision Title]`). These use square brackets, not double-curly-braces, so they won't collide with the `{{VAR}}` token pattern. Do NOT change the placeholder style in those sections.

---

### Task 3 — Add render call to `new-project`

**File:** `new-project`, in the file-creation block (~line 229–237)

Add one `render_template` call after the existing renders and before the `git init` block. The `docs/` directory is already created on line 223 (`mkdir -p "${TARGET_DIR}/docs"`), so no directory creation needed.

```bash
render_template "${TEMPLATE_DIR}/MEASUREMENT.md.tmpl" "${TARGET_DIR}/docs/MEASUREMENT.md"
```

Insert this line after line 232 (`append_stack_sections`) and before line 233 (`ln -s "AGENTS.md"`). Exact placement doesn't matter much — just keep it grouped with the other render calls.

Also update the dry-run output (~line 201) to mention the measurement file is included. This is optional but nice — a one-line echo addition:

```bash
echo "[dry-run] Would create directory and files (including docs/MEASUREMENT.md)"
```

---

### Task 4 — Add template render smoke test to `check`

**File:** `check`, after the existing smoke checks (~line 42)

Add a test that renders `MEASUREMENT.md.tmpl` to `/tmp` and verifies the output contains expected substituted values and no un-replaced `{{` tokens.

```bash
echo "==> MEASUREMENT.md template render smoke check"
(
  # Minimal render test — verify tokens get replaced and no raw {{VAR}} remains
  export PROJECT_NAME="smoke-test-project"
  export TECH_STACK="bash, shellcheck"
  export DESCRIPTION="Smoke test"
  export AUTHOR="Test Author"
  export GITHUB_OWNER="testowner"
  export WEBSITE="test.dev"
  export YEAR="2026"
  export DATE_TODAY="2026-01-15"

  TMPL="${SCRIPT_DIR}/../templates/empty/MEASUREMENT.md.tmpl"
  OUT="/tmp/measurement-smoke-test.md"

  # Re-source the render function from new-project (it's not exported)
  # Instead, just do a direct sed check:
  sed \
    -e "s/{{PROJECT_NAME}}/smoke-test-project/g" \
    -e "s/{{TECH_STACK}}/bash, shellcheck/g" \
    -e "s/{{AUTHOR}}/Test Author/g" \
    -e "s/{{GITHUB_OWNER}}/testowner/g" \
    -e "s/{{WEBSITE}}/test.dev/g" \
    -e "s/{{YEAR}}/2026/g" \
    -e "s/{{DATE_TODAY}}/2026-01-15/g" \
    -e "s/{{DESCRIPTION}}/Smoke test/g" \
    "$TMPL" > "$OUT"

  # Verify substitutions landed
  grep -q "smoke-test-project" "$OUT" || { echo "FAIL: PROJECT_NAME not rendered"; exit 1; }
  grep -q "bash, shellcheck" "$OUT" || { echo "FAIL: TECH_STACK not rendered"; exit 1; }
  grep -q "2026-01-15" "$OUT" || { echo "FAIL: DATE_TODAY not rendered"; exit 1; }
  grep -q "testowner" "$OUT" || { echo "FAIL: GITHUB_OWNER not rendered"; exit 1; }

  # Verify no un-replaced tokens remain
  if grep -qE '\{\{[A-Z_]+\}\}' "$OUT"; then
    echo "FAIL: un-replaced {{TOKEN}} found in rendered output:"
    grep -nE '\{\{[A-Z_]+\}\}' "$OUT"
    exit 1
  fi

  rm -f "$OUT"
)
```

> **Footgun:** The smoke test duplicates the sed expressions rather than calling `render_template` directly, because `render_template` is a function inside `new-project` (not exported/sourced by `check`). This is intentional — extracting `render_template` into `lib/common.sh` would be a nice follow-up but is out of scope for this task.

---

## Out of Scope

- **Do not refactor `render_template()` into a shared library.** The duplication in the smoke test is accepted.
- **Do not modify any other templates** (`README.md.tmpl`, `AGENTS.md.tmpl`, `gitignore.tmpl`, `LICENSE-MIT.tmpl`).
- **Do not add new CLI flags** (e.g., `--no-measurement`). Every project gets the file. If someone doesn't want it, they can delete it.
- **Do not add stack-conditional content to MEASUREMENT.md.** Unlike `AGENTS.md` which has Node/Python sections, the measurement framework is stack-agnostic. No `should_include_*` logic.
- **Do not modify `agent-session`, `sync-projects`, `bootstrap-home-links`, or `setup-claude-mcps`.**
- **Do not install new packages or dependencies.**

---

## Acceptance Criteria

- [ ] `scripts/new-project --name test-proj --stack "node, typescript" --no-remote --projects-dir /tmp` produces `/tmp/test-proj/docs/MEASUREMENT.md`
- [ ] The rendered file contains `test-proj` as the project name (not `{{PROJECT_NAME}}`)
- [ ] The rendered file contains `node, typescript` as the stack
- [ ] The rendered file contains `https://github.com/alexperreira/test-proj` as the repo URL
- [ ] The rendered file contains today's date (`YYYY-MM-DD` format) as the start date
- [ ] The rendered file contains `Planning` as the status
- [ ] The rendered file contains no un-replaced `{{TOKEN}}` patterns
- [ ] All 10 sections of the measurement framework are present in the output
- [ ] Markdown table formatting is intact (pipes align, no mangled rows)
- [ ] `scripts/check` passes (including the new smoke test)
- [ ] `scripts/check --require-shellcheck` passes (if shellcheck is installed)
- [ ] Existing `new-project` behavior is unchanged — all other generated files identical to before
- [ ] The initial `git commit` in the new project includes `docs/MEASUREMENT.md`

---

_Pass this document directly to CC. All tasks are self-contained and executable sequentially._
_Archive to: docs/archive/ADD_MEASUREMENT_FRAMEWORK_TO_BOOTSTRAP.md after completion._