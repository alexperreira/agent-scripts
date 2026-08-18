---
name: adr
description: >
  Produces Architecture Decision Records (ADRs) — lightweight, consistent .md documents that
  capture why a technical decision was made, what alternatives were considered, and what
  consequences follow. Use this skill whenever Alex makes a significant technical choice during
  planning (e.g. "let's go with X instead of Y"), asks to "record this decision", "write an ADR",
  "capture why we chose this", or "document this so we don't re-litigate it." Also trigger
  proactively when a design conversation reaches a clear conclusion — even if Alex doesn't say
  "ADR" — especially for decisions involving: architecture, library/framework selection, API
  design, data modeling, auth strategy, deployment approach, or any choice that would be painful
  to reverse. ADRs are the institutional memory that prevents settled debates from reopening and
  gives future contributors (human or AI) the reasoning behind the codebase's shape.
---

# Architecture Decision Record (ADR)

Produces `.md` ADR files that capture technical decisions in a lightweight, consistent format.
ADRs are not design documents — they are decision documents. The goal is to record *why* a
choice was made, not exhaustively document *what* was built.

---

## Core Principles

1. **Decisions, not descriptions.** An ADR captures the moment of choice: the forces in play, the
   alternatives considered, and the reasoning that produced the outcome. Future readers need to
   understand *why*, not just *what*.

2. **Reopening an Accepted ADR requires a superseding ADR.**

3. **Capture the tradeoffs, not just the win.** An ADR that only explains why the chosen option
   is great is not useful. The Consequences section must name what was given up or what new
   obligations were created.

---

## Hard Constraints on the Document

These govern how the template below is filled:

- **Under ~60 lines total.** If it's growing longer, it's becoming a design doc — split it.
- **The Alternatives table has 2–4 rows.** More than 4 means the decision space wasn't narrowed
  before the ADR was written. Fewer than 2 means the alternatives weren't captured.

---

## Document Structure

Every ADR follows this structure. Omit sections only if genuinely not applicable.

````markdown
# ADR-[NNN]: [Short Decision Title]

_Date: [Month YYYY] | Status: [Proposed | Accepted | Deprecated | Superseded by ADR-NNN]_

---

## Context

[2–5 sentences. What situation forced this decision? What constraints, requirements, or pressures
were in play? What was the state of the world when this decision was made?

Good: "The API needed to support both mobile and web clients with different auth requirements.
Session-based auth would have required server-side state we weren't prepared to manage at
current scale."

Bad: "We needed to pick an auth approach."]

---

## Decision

[One clear statement of what was decided. Start with "We will..." or "We have decided to...".
Then 2–4 sentences of the core reasoning — the most important factors that drove the choice.
This should be readable in isolation.]

---

## Alternatives Considered

| Option | Why Rejected |
|---|---|
| [Alternative A] | [One sentence — the decisive reason it was ruled out] |
| [Alternative B] | [One sentence] |
| [Status quo / do nothing] | [If applicable — why inaction wasn't acceptable] |

---

## Consequences

**Positive:**
- [What becomes easier, safer, faster, or cheaper as a result]
- [What risk is mitigated]

**Negative / Tradeoffs:**
- [What becomes harder or more expensive]
- [What new obligation or constraint this creates]
- [What was explicitly given up]

**Follow-on decisions required:**
- [Any decision this one defers or creates — e.g. "Token revocation strategy is TBD — see ADR-012"]

---

## Related

- [ADR-NNN: Related decision title] — [one-phrase relationship, e.g. "supersedes", "depends on", "informed by"]
- [Task doc or issue reference, if applicable]
````

---

## Status Values

| Status | Meaning |
|---|---|
| **Proposed** | Decision is under discussion — not yet binding |
| **Accepted** | Decision is made and in effect |
| **Deprecated** | Decision no longer applies but was not replaced by a specific ADR |
| **Superseded by ADR-NNNN** | A later ADR overrides this one — link to it |

Accepted is the default status when writing an ADR after a decision has already been made in
conversation. Use Proposed only when the ADR itself is meant to drive or document an open
discussion.

**Superseding is a two-file edit.** An ADR that overturns an earlier one names it in its `Related`
section ("supersedes ADR-NNNN"), and the earlier ADR's status is changed to
`Superseded by ADR-NNNN`. Never leave the old ADR reading `Accepted`.

---

## Numbering

ADRs are numbered sequentially: `ADR-001`, `ADR-002`, etc. If no existing ADRs are present in
the project, start at `ADR-001`. If a docs/adr/ directory exists, check the highest existing
number and increment.

Filename format: `ADR-NNN-short-kebab-case-title.md`
Example: `ADR-007-jwt-over-session-auth.md`

---

## When to Write an ADR

Write one whenever a decision meets one or more of these criteria:

- **Hard to reverse** — switching would require significant rework (auth strategy, DB choice,
  API shape, monorepo vs. polyrepo)
- **Non-obvious** — a reasonable engineer might make a different choice without context
- **Debated** — the team considered multiple options before deciding
- **Load-bearing** — other future decisions depend on this one being stable
- **Likely to be questioned** — someone will ask "why did we do it this way?" within a year

Skip ADRs for obvious or trivially reversible choices: "we used `date-fns` for date formatting"
doesn't need an ADR unless the choice was contested. If nothing in the conversation clears this
bar, say so — *"no ADR-worthy decision here"* — rather than writing one to have written one.

---

## Extracting ADRs from Conversation

When a decision emerges from a planning conversation rather than being explicitly called out:

1. **Identify the decision point** — the moment the conversation committed to a specific approach
2. **Reconstruct the forces** — what constraints or requirements drove the choice (from context)
3. **Name the rejected alternatives** — what was discussed but not chosen
4. **Infer the tradeoffs** — what the chosen approach gives up (be honest, not promotional)

**Completion criterion:** every option named anywhere in the conversation appears as a row in
Alternatives Considered, or the ADR states why it was excluded. The Consequences → Negative list
has at least as many entries as Positive.

**Sourcing rule:** each Alternatives row must cite where in the conversation it was raised. If no
alternatives were named, ask; do not synthesize one.

---

## Output Instructions

- Output: a `.md` file at `docs/adr/ADR-NNN-title.md` (or `adr/` if no `docs/` dir)
- If the project has no ADR directory yet, note in the file footer:
  `_Create docs/adr/ and add this as the first entry. Consider adding a README.md to that
  directory linking all ADRs by number._`
- Date format: `Month YYYY` (e.g. `March 2026`)
- A task doc implementing this ADR carries its number in the **Decisions** row
  (`task-doc-generator`)
