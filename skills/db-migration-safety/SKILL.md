---
name: db-migration-safety
description: >
  Reviews schema changes for safety: destructive operations, zero-downtime patterns, rollback
  plans, backfill requirements, and lock risk. Use this skill whenever Alex is writing or
  reviewing a DB migration, asks "is this migration safe", "how do I add this column without
  downtime", "can I drop this table", or is planning any schema change — column add/drop/rename,
  index creation, table rename, type change, constraint addition, or data backfill. Also trigger
  proactively when a task doc or ADR involves schema changes, even if the word "migration" isn't
  used. The cost of a bad migration in production is high and often irreversible — always run
  this skill before migration code is written or executed.
---

# Database Migration Safety

Reviews schema changes for correctness, safety, and zero-downtime viability before any migration
is written or executed.

**This skill owns migration risk tiers.** The tier assigned here is the canonical label: a task doc
(`task-doc-generator`) carries it verbatim in its **Risk** row rather than translating it into
Low/Medium/High.

---

## Core Principles

1. **Classify before writing.** Every migration falls into one of three risk tiers (see below).
   Determine the tier before writing a single line of SQL.

2. **Zero-downtime by default.** Any migration that requires downtime must be explicitly approved
   and scheduled. The default posture is: if it can't run safely while the app is serving
   traffic, redesign it until it can.

3. **One change class per migration.** DDL migrations contain only DDL. Data changes (backfills)
   ship separately — they have different performance profiles, rollback characteristics, and lock
   behaviors.

4. **Every migration needs a rollback plan.** Before writing the forward migration, write the
   reverse. If the reverse is impossible or destructive, that's a signal the forward migration
   needs to be redesigned.

5. **Backfills run as background jobs.** Large data backfills run as a background job or separate
   script, never inline in a migration.

6. **Size the migration against production.** Runtime is a function of production row counts, not
   dev data. Read the real number before estimating (see the Operational checklist).

---

## Risk Tier Classification

Classify every migration before reviewing it. **Tier 2/3 → read
`references/zero-downtime-patterns.md` for the matching recipe.**

### 🟢 Tier 1 — Safe (zero-downtime, non-destructive)
These can run on a live database without coordination:
- Adding a nullable column with no default
- Adding a new table
- Adding an index `CONCURRENTLY` (Postgres) or equivalent non-locking syntax
- Adding a foreign key without `NOT VALID` constraint enforcement
- Dropping an index

**Review focus:** Correctness only. Confirm the change matches intent.

---

### 🟡 Tier 2 — Caution (potential lock or coordination required)
These require review and may need coordination with deploys:
- Adding a column with a `NOT NULL` constraint and a `DEFAULT` value
  _(Postgres 11+: safe. Older: rewrites the whole table.)_
- Adding a `NOT NULL` constraint to an existing column
  _(Requires all existing rows to already satisfy it, or a concurrent backfill first.)_
- Creating an index without `CONCURRENTLY`
  _(Locks table for the duration — safe only on small tables or during maintenance.)_
- Adding a foreign key with immediate validation
- Changing a column's nullability
- Renaming a column or table _(breaks running app code that references old name)_

**Review focus:** Lock risk, deploy coordination, backward compatibility with currently-deployed
code.

---

### 🔴 Tier 3 — Dangerous (destructive or high-impact)
These require explicit sign-off, a rollback plan, and usually a maintenance window or multi-step
expand/contract sequence:
- Dropping a column
- Dropping a table
- Changing a column's data type
- Removing a constraint that app code may rely on
- Any migration that requires a full table rewrite

**Review focus:** Is this reversible? Is existing app code still safe after this runs? Is there
a multi-step expand/contract plan?

---

## Dropping a Column

Dropping a column is the **contract** phase of an expand/contract sequence, never a standalone
migration. Drop a column only after a deploy removing all reads and writes has been live and
verified in production. Full sequence: `references/zero-downtime-patterns.md`.

---

## Rollback Plan Template

Every migration review must produce a rollback plan. Document it before the migration runs.

```markdown
## Rollback Plan: [Migration Name]

**Forward migration:** [one-line description]
**Rollback feasible:** Yes / No / Partial

**If rollback is needed:**
1. [Step 1 — e.g. "Run reverse migration: ALTER TABLE ..."]
2. [Step 2 — e.g. "Redeploy previous app version"]
3. [Step 3 — e.g. "Verify no data loss by checking row count"]

**Data loss risk on rollback:** None / Low / High
[If High: describe what data would be lost and whether it's recoverable]

**Rollback window:** [How long after forward migration is rollback viable?
e.g. "Until backfill job completes — after that, dropping new column loses backfilled data"]
```

---

## Backfill Safety Rules

When a migration requires existing rows to be updated:

1. **Run it as a background job or separate script.**
2. **Batch the writes.** Update rows in batches of 100–1000, with a short sleep between batches
   to avoid replication lag and lock contention.
3. **Make the backfill idempotent.** It must be safe to run twice: `WHERE new_col IS NULL`
   or equivalent.
4. **Verify completion before adding constraints.** Do not add `NOT NULL` or a unique constraint
   until the backfill is verified complete.
5. **Monitor replication lag** during the backfill if running a replicated setup.

Batched-backfill implementation (Postgres `DO $$` loop with batch size and sleep):
`references/backfill.md` — read it when writing the backfill script.

---

## Migration Review Checklist

Run through this before approving any migration:

### Classification
- [ ] Tier assigned (1 / 2 / 3)
- [ ] If Tier 3: explicit sign-off obtained and rollback plan documented

### Lock risk
- [ ] Indexes created `CONCURRENTLY` (or the equivalent non-locking syntax for the engine)
- [ ] `NOT NULL` column adds with a `DEFAULT` verified against Postgres >= 11
- [ ] Table rewrites scheduled outside business hours

### Backward compatibility
- [ ] Currently-deployed app code still works after this migration runs
- [ ] If renaming: expand/contract plan in place across multiple deploys
- [ ] If dropping: confirmed no app code references the removed object

### Data safety
- [ ] Backfills run as a separate background job, not inline in the migration
- [ ] Backfill job is idempotent
- [ ] Rollback plan documented

### Operational
- [ ] Row count of every touched table read from production — state the number and where you
      read it. A guessed count fails this check.
- [ ] Estimated runtime derived from that count and documented
- [ ] If > 1 minute estimated: maintenance window scheduled or async approach designed
- [ ] ORM model updated in sync with schema change

---

## Output Format

When reviewing a migration, produce:

1. **Tier classification** with one-sentence rationale — this label is what the task doc's **Risk**
   row carries verbatim
2. **Risk findings** — any checklist failures, lock risks, or compatibility issues
3. **Recommended approach** — safe rewrite if the original is unsafe
4. **Rollback plan** — always, even if trivial
5. **Open questions** — anything that requires confirmation before proceeding

If the migration is safe as written, say so clearly — don't manufacture concerns.
