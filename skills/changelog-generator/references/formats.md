# Alternate Output Formats

Read this when the audience is not an in-repo `CHANGELOG.md`. Format A (Keep a Changelog) lives
inline in SKILL.md and is the default; these two are the stakeholder-facing alternatives.

---

## Format B — GitHub / Linear Release Notes (stakeholder-facing)

Use for: GitHub Releases, Linear changelog, Notion release log, Slack announcements.

````markdown
## What's new in [Version / Sprint Name]

**Released:** [Date]

### Highlights
[2–4 sentence narrative summary of the release theme — what problem it solves, what becomes
possible. Not a list. Written for a technical but non-implementation audience.]

### New Features
- **[Feature name]:** [One sentence describing user-visible change and its value]

### Bug Fixes
- [Symptom fixed, not cause] — [link]

### ⚠️ Action Required
> [If any breaking change or migration is needed, put it here in a blockquote. Include exact
> steps. This section is mandatory if any breaking change is present.]

### Under the Hood
[Optional. 1–3 bullets for internal/infra changes with no direct user impact.]
````

---

## Format C — Plain Prose (stakeholder memo / Slack)

Use for: Non-technical audiences, executive summaries, team announcements.

````markdown
**[Product / Feature Name] Update — [Month YYYY]**

[2–3 sentences: what shipped and why it matters to the reader. Avoid jargon.]

Key changes:
- [Plain-English description, benefit-first]
- [Another change]

If you're affected: [Only include if action is required. State exactly what to do.]

Questions? [Contact or link]
````
