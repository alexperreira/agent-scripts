---
name: changelog-generator
description: >
  Converts completed task docs, commit logs, PR descriptions, or sprint notes into structured,
  human-readable release notes and changelogs. Use this skill whenever Alex says "write release
  notes", "generate a changelog", "summarize what shipped", "what changed in this release",
  "draft the CHANGELOG entry", or finishes a sprint/milestone and needs to document it. Also
  trigger proactively when a set of task docs has been completed and the conversation turns toward
  shipping, tagging a release, communicating changes to stakeholders, or updating a CHANGELOG.md.
  Don't wait to be asked — if a release is wrapping up and nothing has been documented yet, offer
  to generate it.
---

# Changelog / Release Notes Generator

Transforms raw engineering artifacts — completed task docs, commit messages, PR descriptions,
branch diffs, sprint recaps — into structured, audience-appropriate release documentation.

A good changelog is not a commit dump. It answers: *What changed? Why does it matter? Does
anything break? What do I need to do?*

---

## Core Principles

1. **Audience determines format.** Internal engineering changelogs (CHANGELOG.md) and
   external-facing release notes are different documents with different levels of technical depth.
   Always confirm or infer the audience before drafting.

2. **One entry per logical change, grouped under Features / Fixes / Breaking Changes.** Collapse
   low-signal commits (typos, formatting, minor refactors) into the entry they serve.

3. **Breaking changes get top billing.** Breaking Changes is the first section of the output.

   Task docs written by `task-doc-generator` carry a **`Breaking`** row in their Overview table
   (`None / API shape / DB schema / env var / behavior`). Completed docs are archived to
   `docs/archive/*.md`. So the extraction is mechanical, not inferential: **read every archived
   task doc since the last tag; each one whose `Breaking` row is not `None` becomes an entry,
   carrying that row's stated consumer action as its migration note.**

   For inputs without that row — raw commits, PR descriptions, a verbal recap — infer as before,
   and say in the output which entries were inferred rather than read. If a task doc's `Breaking`
   row is missing entirely, flag it rather than assuming `None`; an omitted row and a stated
   `None` are different facts.

4. **Link to the source.** Every entry should reference its origin: task doc filename, PR number,
   commit hash, or issue ID. This preserves traceability without bloating the prose.

5. **Migration notes are non-optional.** If a change requires action from an operator, developer,
   or end user, include a clear "Migration / Action Required" callout with specific steps.

6. **Version and date on every entry.** If no version exists yet, use `[Unreleased]` per Keep a
   Changelog convention.

---

## Input Sources

The skill accepts any combination of the following as raw input:

| Source | What to extract |
|---|---|
| **Task docs (.md)** | Title, scope, affected files, acceptance criteria completed, and the **`Breaking` row** from the Overview table |
| **Git log / commits** | Subject line, body, PR refs (`#NNN`) |
| **PR descriptions** | Summary, linked issues, "breaking change" checkboxes |
| **Sprint board export** | Done tickets, labels, assignees |
| **Verbal recap** | Freeform description of what shipped — ask clarifying questions |

If input is ambiguous or incomplete, ask before drafting. Specifically confirm:
- Target version/tag (or use `[Unreleased]`)
- Release date (or omit / use "TBD")
- Audience (internal engineers, external developers, end users, stakeholders)
- Format preference (Keep a Changelog, GitHub Releases, plain prose, Notion-style)

---

## Output Format — CHANGELOG.md (Keep a Changelog style)

The default. Use for: `CHANGELOG.md` files in repos, internal eng records.

````markdown
## [X.Y.Z] — YYYY-MM-DD

### ⚠️ Breaking Changes
- **`fieldName` removed from `/api/endpoint` response** — Previously returned `null` on missing
  records; now returns `404`. Update any clients that handle `null` explicitly. ([#123])

### Added
- [Short present-tense description of new capability] ([#NNN] / `TASK_SLUG.md`)
- [Another addition]

### Changed
- [Behavior or interface change that is non-breaking]

### Fixed
- [Bug fixed — include symptom, not just cause]

### Removed
- [Deprecated feature or endpoint removed]

### Security
- [Security fix — include CVE or severity if known]

---

_Full diff: [compare link or git range]_
````

**Other audiences:** when the target is a GitHub/Linear release, a Notion or Slack announcement, or
a non-technical stakeholder memo, read `references/formats.md` for those two templates.

---

## Entry Writing Rules

These apply to all formats:

- **Present tense for features:** "Adds support for X" not "Added support for X" in CHANGELOG.md
  (past tense is acceptable in narrative formats)
- **User-visible symptom for fixes:** "Fixes crash when uploading files over 10MB" not
  "Fixes null pointer in `FileUploader.handleSubmit()`"
- **One entry per logical change**, not per commit — collapse related commits
- **An entry earns inclusion when a user or operator can observe the change**
- **Every breaking-change entry ends with the exact command or code edit a consumer must make**

---

## Checklist Before Delivering

- [ ] Version number and date present (or `[Unreleased]` if pre-tag)
- [ ] Breaking changes section is first (if any exist)
- [ ] Every breaking change has a migration note
- [ ] No commit-dump entries — all entries are grouped and human-readable
- [ ] Links to source (task doc, PR, issue) included per entry
- [ ] Audience-appropriate format selected
- [ ] `Action Required` callout present if any operator/user action is needed
- [ ] Security fixes labeled with severity if known
- [ ] Every input artifact (commit, PR, archived task doc) maps to exactly one entry or appears in
      a "deliberately omitted" list with a reason

---

## Output Instructions

- Default output: inline in conversation, formatted as a fenced markdown block ready to copy
- If the user wants a file: write `CHANGELOG.md` or `RELEASE_NOTES_vX.Y.Z.md` to the filesystem
- When appending to an existing `CHANGELOG.md`, preserve all prior entries — prepend the new
  entry at the top under the `[Unreleased]` header or a versioned header
- Date format: `YYYY-MM-DD` for CHANGELOG.md, `Month YYYY` in prose formats
- If version is not yet decided, use `## [Unreleased]` and note that the version placeholder
  should be replaced before tagging
- If every input artifact is internal-only with nothing user- or operator-observable, say so —
  *"nothing in this range is changelog-worthy"* — and list what was omitted and why
