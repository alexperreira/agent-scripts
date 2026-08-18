# API Latency Profiling

Read when Phase 2 identifies the **API / serialization** layer (request lifecycle latency) as the
bottleneck.

---

## Breakdown pattern

Instrument every significant async boundary in the request lifecycle:

```ts
export async function handler(req, res) {
  const timings: Record<string, number> = {};
  const mark = (label: string) => { timings[label] = performance.now(); };

  mark('start');
  const user = await auth.verify(req);
  mark('auth');

  const data = await service.getData(user.id);
  mark('service');

  const serialized = serialize(data);
  mark('serialize');

  res.setHeader('Server-Timing',
    Object.entries(timings)
      .map(([k, v], i, arr) =>
        i === 0 ? null : `${k};dur=${(v - arr[i-1][1]).toFixed(1)}`
      )
      .filter(Boolean)
      .join(', ')
  );

  return res.json({ ok: true, data: serialized });
}
```

The `Server-Timing` header makes timings visible in the browser Network tab and in logs.

---

## Common API latency sources

| Source | Detection | Fix |
|---|---|---|
| Slow DB query | `EXPLAIN ANALYZE` | Index, query rewrite, or eager load |
| Sequential awaits that could be parallel | Review handler code | `Promise.all([...])` |
| Overfetching — returning unused fields | Compare response size to what client uses | Field selection / projection |
| No connection pooling | Check DB client config | Enable pooling (PgBouncer, Prisma pool) |
| Cold start (serverless) | First-request latency spike | Warming strategy or move to persistent process |
| Downstream service latency | Per-layer timing | Cache, circuit breaker, or async processing |
