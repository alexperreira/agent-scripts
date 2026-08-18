---
name: threat-modeling
description: >
  Identifies attack surfaces for a given feature or system: STRIDE-style analysis, trust
  boundaries, data flow risks, and mitigation recommendations. Use this skill whenever Alex
  is designing a new feature that handles user data, authentication, file uploads, webhooks,
  external integrations, or payments — or asks "what could go wrong security-wise", "is this
  secure", "what are the attack surfaces here", or "should I be worried about X". Also trigger
  proactively when a task doc introduces a new API endpoint, a new data model with sensitive
  fields, or a new trust boundary — before implementation starts. Finding threats in design
  is 10x cheaper than finding them in production.
---

# Threat Modeling

Identifies attack surfaces, trust boundaries, and security risks for a feature or system —
before implementation, not after.

Threat modeling is not a security audit of existing code. It's a structured way to ask "what
could an attacker do here?" during design, when the answer is "change the design" rather than
"patch the code."

---

## Core Principles

1. **Model threats against the design, not the implementation.** The goal is to find structural
   problems — missing auth checks, over-permissive trust, unsafe data flows — not code bugs.
   Code bugs are caught in code review. Design flaws are caught here.

2. **Define trust boundaries explicitly.** Every place where data crosses from one trust level
   to another is a potential attack surface: internet → server, server → DB, user input →
   system command, webhook payload → business logic.

3. **Threat model the realistic attacker.** Consider: an authenticated user trying to access
   another user's data; an unauthenticated caller probing the API; a malicious webhook payload;
   a compromised third-party dependency.

4. **Every threat needs a mitigation or an accepted risk.** Unmitigated threats are not
   automatically acceptable. If a risk is accepted, document why — threat, likelihood,
   impact, and the explicit decision to accept it.

---

## STRIDE Framework

Use STRIDE to systematically enumerate threat categories. For each component in the system,
ask each question.

| Threat | Question to ask | Example |
|---|---|---|
| **S**poofing | Can an attacker impersonate a user, service, or component? | JWT with weak signing key; no webhook signature verification |
| **T**ampering | Can an attacker modify data in transit or at rest? | Unsigned payload; user-editable field that becomes a system value |
| **R**epudiation | Can an attacker deny having performed an action? | No audit log; action taken without auth record |
| **I**nformation Disclosure | Can an attacker read data they shouldn't? | IDOR; verbose error messages; over-permissive API response |
| **D**enial of Service | Can an attacker degrade or disable the service? | No rate limiting; unbounded query; large file upload without size cap |
| **E**levation of Privilege | Can an attacker gain more permissions than they should have? | Missing role check; insecure direct object reference; mass assignment |

---

## Trust Boundary Identification

Map every place where data crosses a trust boundary. These are the locations that require
explicit validation, authentication, and authorization.

**Common trust boundaries:**

| Boundary | Threats to check |
|---|---|
| Internet → API | Auth required? Input validated? Rate limited? |
| User A → User B's data | Every read and write scoped by owner? (see auth-authorization-audit) |
| Webhook payload → business logic | Signature verified? Replay protected? Idempotent? |
| API → DB | Parameterized queries? Principle of least privilege on DB user? |
| File upload → filesystem/storage | Type validated? Size capped? Path traversal prevented? |
| Third-party API response → app logic | Response validated? Failure handled? Secrets in transit? |
| Environment variable → runtime config | Rotatable? Reaches the process only via env or a secrets manager? (see secrets-env-management) |
| Admin role → privileged action | Separate auth factor? Audit logged? |

---

## Threat Enumeration by Feature Type

**When the feature under design is an auth flow, a CRUD surface, a file upload, a webhook
receiver, or a background job, read `references/feature-threat-catalog.md` for that type's
starting threat list before running STRIDE.**

---

## Completeness Bar

A threat model is done when both of these hold:

- **Scope is complete** when every route, background job, and external caller touched by the
  diff is named in the Scope section.
- **Enumeration is complete** when every trust-boundary row carries at least one threat, or
  the literal string `no threat: <reason>`.

---

## Output Format

```markdown
## Threat Model: [Feature Name]

### Scope
[Every route, job, and external caller touched by this change, named explicitly]

### Trust Boundaries
| Boundary | In scope? |
|---|---|
| [e.g. Internet → POST /v1/uploads] | Yes |
| [e.g. Authenticated user → other users' files] | Yes |

### Threats Identified

#### 🔴 High — [Short label]
**Category:** [STRIDE category]
**Threat:** [What an attacker could do]
**Vector:** [How — specific to this design]
**Mitigation:** [What must be in place before shipping]
**Status:** [ ] Not mitigated / [x] Mitigated by [control name]

#### 🟡 Medium — [Short label]
...

#### 🔵 Low / Accepted Risk — [Short label]
**Accepted because:** [Explicit rationale]

### Mitigations Required Before Shipping
- [ ] [Control that must be implemented]
- [ ] [Control that must be implemented]

### Open Questions
- [Any design ambiguity that affects the threat surface]
```

---

## Severity Classification

*When in doubt, rate higher.*

| Severity | Criteria |
|---|---|
| 🔴 High | Exploitable without authentication, or enables access to any user's data, or causes data loss |
| 🟡 Medium | Requires authentication to exploit, or limited blast radius, or requires user interaction |
| 🔵 Low | Theoretical, difficult to exploit in practice, or impact is minimal |

---

If the design has no threats beyond the ones its existing controls already mitigate, say so
clearly and list the controls that cover them — don't manufacture threats to fill the table.
