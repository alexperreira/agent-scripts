# Severity Definitions and Action Item Anti-Patterns

Read this when assigning a SEV level to the header, or when screening draft action items.

---

## Severity Definitions

Use these if the team doesn't have their own:

| Level | Definition |
|---|---|
| **SEV-1** | Full service outage or data loss — all hands, immediate response |
| **SEV-2** | Significant degradation affecting a substantial portion of users |
| **SEV-3** | Partial degradation with workaround available; limited user impact |
| **SEV-4** | Minor issue; monitoring only; no user-visible impact |

---

## Action Item Anti-Patterns

Flag these if they appear in draft action items — they are not actionable:

| Anti-pattern | Replace with |
|---|---|
| "Improve monitoring" | "Add [specific alert] for [metric] with threshold [X] by [date]" |
| "Be more careful" | (Remove entirely — violates blameless principle) |
| "Increase testing" | "Add integration test covering [specific scenario] to [test suite]" |
| "Communicate better" | "Add [specific step] to incident runbook for [role]" |
| "Fix the process" | Describe the specific process change with a named owner |
