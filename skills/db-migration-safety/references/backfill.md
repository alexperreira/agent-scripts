# Batched Backfill Implementation

Read this when writing the backfill script for a migration that requires existing rows to be
updated. The safety rules live in SKILL.md; this is the implementation.

---

## Safe batched backfill pattern (Postgres)

```sql
-- Safe batched backfill pattern
DO $$
DECLARE
  batch_size INT := 500;
  rows_updated INT;
BEGIN
  LOOP
    UPDATE users
    SET preferences = '{}'
    WHERE id IN (
      SELECT id FROM users WHERE preferences IS NULL LIMIT batch_size
    );
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    EXIT WHEN rows_updated = 0;
    PERFORM pg_sleep(0.05); -- 50ms pause between batches
  END LOOP;
END $$;
```

- Batch size 500 sits inside the 100–1000 range; lower it if replication lag climbs.
- The `WHERE preferences IS NULL` predicate is what makes the job idempotent — it must be safe
  to run twice.
- The `pg_sleep(0.05)` pause is what keeps replication lag and lock contention bounded. Do not
  remove it to make the job finish faster.
