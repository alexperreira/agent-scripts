# DB Query Profiling

Read when Phase 2 identifies the **DB / persistence** layer as the bottleneck.

---

## The N+1 Problem

Occurs when fetching a list of N records and then issuing one query per record to fetch related
data. It is the most frequent backend cause of latency that scales with data volume.

**Symptom:** query count in logs scales linearly with result set size.

**Detection:**
```ts
// Enable query logging in your ORM
// Prisma:
const prisma = new PrismaClient({ log: ['query'] });

// Look for repeated queries with different IDs:
// SELECT * FROM comments WHERE post_id = 1
// SELECT * FROM comments WHERE post_id = 2
// SELECT * FROM comments WHERE post_id = 3  ← N+1
```

**Fix:** eager-load relations in a single query.
```ts
// Prisma — wrong (N+1)
const posts = await prisma.post.findMany();
for (const post of posts) {
  post.comments = await prisma.comment.findMany({ where: { postId: post.id } });
}

// Prisma — right (1 query with JOIN)
const posts = await prisma.post.findMany({
  include: { comments: true }
});
```

---

## EXPLAIN ANALYZE

Run on any slow query before adding indexes or rewriting.

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM sessions
WHERE user_id = 'usr_abc123'
ORDER BY created_at DESC
LIMIT 20;
```

**What to look for:**

| Node type | What it means | Action |
|---|---|---|
| `Seq Scan` on large table | Full table scan — no usable index | Add index on filter/sort columns |
| `Hash Join` on large sets | Joining large tables in memory | Check if join columns are indexed |
| High `rows` estimate vs actual | Stale statistics | Run `ANALYZE tablename` |
| `Nested Loop` with many iterations | N+1 at the query level | Rewrite as JOIN or use `IN (...)` |
| High `Buffers: hit` miss ratio | Data not in cache | May need query optimization or more RAM |

**Index creation checklist:**
- Index columns used in `WHERE` clauses on large tables
- Index columns used in `ORDER BY` if also filtered
- Use composite indexes when filtering on multiple columns together: `(user_id, created_at)`
- Always use `CREATE INDEX CONCURRENTLY` in production (see `db-migration-safety`)

---

## Slow Query Log

For sustained investigation, enable the slow query log:

```sql
-- Postgres: log queries taking > 100ms
SET log_min_duration_statement = 100;
```

Review with `pg_stat_statements` for aggregate patterns:
```sql
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```
