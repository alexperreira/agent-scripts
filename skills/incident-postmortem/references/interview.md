# Incident Intake Questions

Read this only when the incident facts were not already supplied. Ask in one pass — don't drip one
question at a time.

---

**Incident basics:**
- What service / feature was affected?
- When did it start and when was it resolved? (timestamps, timezone)
- Who detected it and how? (alert, customer report, internal)
- What was the immediate mitigation (rollback, config change, hotfix)?

**Impact:**
- How many users / requests / records were affected?
- Was any data lost or corrupted?
- Any revenue or SLA impact?
- Were any external stakeholders (customers, partners) notified?

**Cause:**
- What was the triggering change or event?
- What made the system vulnerable to that trigger?
- Were any warning signals missed before the incident escalated?

**Response:**
- Was the on-call / incident response process followed?
- What slowed down detection or resolution?
