# Zero-Downtime Migration Patterns

Read this when a migration is classified **Tier 2** or **Tier 3** — find the matching recipe below
and rewrite the migration to it.

---

## Adding a NOT NULL column with a default

**Wrong (Tier 3 in Postgres < 11, rewrites table):**
```sql
ALTER TABLE users ADD COLUMN preferences jsonb NOT NULL DEFAULT '{}';
```

**Right (3-step expand/contract):**
```sql
-- Migration 1: Add nullable (Tier 1)
ALTER TABLE users ADD COLUMN preferences jsonb;

-- Background job: Backfill existing rows
UPDATE users SET preferences = '{}' WHERE preferences IS NULL;

-- Migration 2: Add constraint after backfill completes (Tier 2)
ALTER TABLE users ALTER COLUMN preferences SET NOT NULL;
ALTER TABLE users ALTER COLUMN preferences SET DEFAULT '{}';
```

---

## Renaming a column

**Wrong (breaks running app code immediately):**
```sql
ALTER TABLE sessions RENAME COLUMN user_id TO owner_id;
```

**Right (expand/contract across two deploys):**
```sql
-- Migration 1: Add new column (Tier 1)
ALTER TABLE sessions ADD COLUMN owner_id uuid;

-- Deploy app code that writes to BOTH columns

-- Background job: Backfill owner_id from user_id

-- Deploy app code that reads from new column only

-- Migration 2: Drop old column (Tier 3, after confirming no reads)
ALTER TABLE sessions DROP COLUMN user_id;
```

---

## Creating an index safely

**Wrong (locks table):**
```sql
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
```

**Right (Postgres):**
```sql
CREATE INDEX CONCURRENTLY idx_sessions_user_id ON sessions(user_id);
```

Note: `CONCURRENTLY` cannot run inside a transaction block. Ensure the migration runner
doesn't wrap it in `BEGIN/COMMIT`.

---

## Dropping a column safely (the contract phase)

Sequence:

1. Deploy app code that no longer reads or writes the column
2. Confirm no queries reference the column in production (logs, query analytics)
3. Run migration to drop the column
4. If using an ORM, remove the column from the model in the same deploy as step 1
