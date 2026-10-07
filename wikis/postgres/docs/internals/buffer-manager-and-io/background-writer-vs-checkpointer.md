# Background writer vs checkpointer vs backend writes

Three kinds of process write dirty buffers:

| Writer | When | Goal |
|---|---|---|
| **Checkpointer** | Each checkpoint, spread over `checkpoint_completion_target` | Bound recovery time — writes *all* dirty buffers |
| **Background writer** | Every `bgwriter_delay` (200 ms), up to `bgwriter_lru_maxpages` (100) per round, guided by `bgwriter_lru_multiplier` (2.0) × recent demand | Keep clean buffers ready ahead of the clock hand |
| **Backends** | When their chosen victim is dirty | Last resort — adds latency to the query |

A healthy system has most writes from the checkpointer, some from the background writer, and very few from client backends.

```sql
-- PG16+: who writes?
SELECT backend_type, sum(writes) AS writes, sum(fsyncs) AS fsyncs
FROM pg_stat_io
WHERE object = 'relation' AND writes > 0
GROUP BY backend_type
ORDER BY writes DESC;

-- Background writer stopping early (raise bgwriter_lru_maxpages)
SELECT buffers_clean, maxwritten_clean, buffers_alloc FROM pg_stat_bgwriter;
```

PG17 moved checkpoint counters to `pg_stat_checkpointer` and removed `buffers_backend` from `pg_stat_bgwriter` — use `pg_stat_io` instead.
