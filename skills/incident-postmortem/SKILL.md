---
name: incident-postmortem
description: >
  Guides a structured blameless post-mortem for production incidents, outages, data issues, or
  significant failures. Use this skill whenever Alex says "we had an incident", "write a
  post-mortem", "the site went down", "something broke in prod", "do a retro on the outage",
  "root cause analysis", or "RCA". Also trigger proactively when a bug, regression, or service
  disruption has just been resolved and the conversation turns to "what happened" or "how do we
  prevent this" — even if no one says "post-mortem" explicitly. Don't wait to be asked if it's
  clear an incident just occurred. Produces a complete post-mortem document: detection timeline,
  root cause, contributing factors, impact assessment, and concrete action items with owners.
---

# Incident Response / Post-mortem

Produces structured, blameless post-mortem documents for production incidents, service
disruptions, data issues, or significant failures.

---

## Core Principles

1. **Blameless by design.** The document names systems, processes, and decisions. **Every causal
   statement has a system, process, or condition as its grammatical subject.** Where a human action
   contributed, describe the conditions that made the action likely.

2. **Timeline is the foundation.** Everything else — root cause, contributing factors, action
   items — is derived from it. Each of detection, escalation, mitigation, and resolution gets its
   own timestamped row.

3. **Assume Swiss cheese: one primary cause, N contributing factors.** Label a primary root cause,
   but always enumerate the contributing factors. A post-mortem that says "root cause: human error"
   is incomplete.

4. **Impact must be quantified.** Vague impact statements ("some users were affected") are not
   useful. Always attempt to quantify: duration, percentage of users affected, error rate, revenue
   impact, data loss volume.

5. **Action items must be actionable.** Each action item needs an owner, a due date, and a
   specific deliverable. "Improve monitoring" is not an action item. "Add P95 latency alert for
   `/api/checkout` with threshold 2s by [date] — owner: [team]" is.

6. **Five Whys without a blame landing.** Keep asking why until you reach a systemic or
   process-level failure — not a person. Good: "Why did this go undetected? → No alert existed for
   this failure mode." Bad: "Why did this happen? → Developer didn't test it."

---

## Reference Files

| Read when | File |
|---|---|
| The incident facts weren't supplied — you need to run the intake pass | `references/interview.md` |
| Assigning a SEV level, or screening draft action items | `references/severity-and-antipatterns.md` |

---

## Document Structure

````markdown
# Post-mortem: [Short Incident Title]

_Date: [YYYY-MM-DD] | Severity: [SEV-1 / SEV-2 / SEV-3] | Status: [Draft / Final]_
_Author(s): [Initials or team] | Reviewed by: [Optional]_

---

## Summary

[2–4 sentences. What happened, when, how long, and high-level impact. Readable in isolation —
this is what gets pasted into Slack or an exec summary.]

**Duration:** [HH:MM from detection to full resolution]
**Impact:** [Quantified — e.g., "~12% of checkout requests returned 500 for 47 minutes"]
**Root Cause:** [One sentence — the primary technical cause]

---

## Timeline

All times in [timezone]. Mark key state transitions: detection, escalation, mitigation, resolution.

| Time (UTC) | Event |
|---|---|
| HH:MM | [What happened — observable event, not inference] |
| HH:MM | [Alert fired / customer report received / team paged] |
| HH:MM | [Engineer began investigation] |
| HH:MM | [Root cause identified] |
| HH:MM | [Mitigation applied — e.g., rollback deployed] |
| HH:MM | [Service fully restored / error rate back to baseline] |
| HH:MM | [Incident declared resolved] |

**Detection lag:** [Time from incident start to detection — highlight if > 5 min]
**Time to mitigation:** [Time from detection to mitigation applied]
**Time to resolution:** [Time from mitigation to full recovery]

---

## Root Cause

[2–4 sentences. Describe the technical root cause: what failed, why it failed, and what made the
system susceptible. This is a systems description, not a blame statement.]

### Five Whys

| Why | Answer |
|---|---|
| Why did [the symptom] occur? | [Technical answer] |
| Why did [that happen]? | [Deeper cause] |
| Why did [that happen]? | [Deeper still] |
| Why did [that happen]? | [Process or system gap] |
| Why did [that happen]? | [Root systemic cause] |

---

## Contributing Factors

These factors did not cause the incident but made it more likely to occur or harder to detect
and resolve.

- **[Factor 1]:** [e.g., "No alert existed for elevated 5xx rate on the checkout endpoint"]
- **[Factor 2]:** [e.g., "Staging environment did not replicate production traffic patterns"]
- **[Factor 3]:** [e.g., "Runbook for this failure mode was outdated"]
- **[Factor 4]:** [e.g., "Deploy happened during peak traffic window without a traffic spike guard"]

---

## Impact Assessment

| Dimension | Detail |
|---|---|
| **Duration** | [Start → End, total elapsed] |
| **Users / Requests affected** | [Count or %, with confidence level] |
| **Error type** | [5xx, data corruption, partial degradation, full outage] |
| **Data loss / corruption** | [None / describe if present] |
| **Revenue / SLA impact** | [If known or estimable] |
| **External notifications sent** | [Yes/No — status page, customer emails, partner alerts] |

---

## What Went Well

[Optional but valuable — name things that limited the blast radius or sped up recovery.]

- [e.g., "Rollback procedure was rehearsed and completed in < 3 minutes"]
- [e.g., "On-call response time was within SLA"]
- [e.g., "Feature flag allowed partial traffic reduction without a deploy"]

---

## Action Items

Every item must have: a specific deliverable, an owner (team or role), and a target date.
Label priority: **P0** (prevents recurrence), **P1** (reduces severity), **P2** (improves response).

| Priority | Action | Owner | Due Date | Addresses factor |
|---|---|---|---|---|
| P0 | [Specific preventive change] | [Team / Role] | [YYYY-MM-DD] | [Factor 1] |
| P0 | [Fix the gap that allowed this to reach production] | [Team] | [Date] | [Factor 2] |
| P1 | [Add or improve the alert that would have caught this earlier] | [Team] | [Date] | [Factor 1] |
| P1 | [Update runbook with this failure mode] | [On-call lead] | [Date] | [Factor 3] |
| P2 | [Improve staging fidelity / test coverage] | [Team] | [Date] | [Factor 4] |

---

## Open Questions

[Track anything that needs follow-up investigation before this post-mortem can be marked Final.]

- [ ] [Question to answer]
- [ ] [Data still being gathered]

---

_Post-mortem review meeting: [Date/link if scheduled]_
_Document status: Draft → In Review → Final_
_Archive to: `docs/postmortems/YYYY-MM-DD-[slug].md`_
````

---

## Closing the Loop

- **Coverage gate:** every contributing factor has at least one action item whose `Addresses
  factor` cell cites it, or an explicit line stating why none is needed. An unmatched contributing
  factor blocks Final status.
- **Draft → Final requires** every Open Questions box checked and every P0 due date in the future.
- **Every P0 action item is emitted as a task doc via `task-doc-generator` before this post-mortem
  is marked Final.**
- An action item that changes a systemic or architectural decision is recorded via `adr`; the ADR
  number goes in the action item row.
- An action item that fixes a security defect is handed to `changelog-generator` for the **Security**
  section of the next release notes.

---

## Output Instructions

- Default output: a `.md` file at `docs/postmortems/YYYY-MM-DD-[slug].md`
- If no filesystem context, produce inline as a fenced markdown block
- Slug format: `kebab-case-short-incident-description` (e.g., `checkout-5xx-deploy-regression`)
- Status starts as `Draft` — mark `Final` only after review meeting or explicit sign-off
- If timeline data is sparse, produce a skeleton with `[TBD]` placeholders and call out what
  information is still needed to complete the document
- If the incident genuinely has one cause and no contributing factors, say so explicitly
  (*"No contributing factors identified beyond the primary cause"*) rather than padding the list
