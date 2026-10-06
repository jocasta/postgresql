# pg_wait_sampling

Samples wait events of every backend at high frequency and aggregates them into a profile — answers "what are sessions actually waiting on?" over time, rather than a single `pg_stat_activity` snapshot.

- **Type:** third-party (Postgres Professional)
- **Preload required:** **Yes**
- **Repo:** <https://github.com/postgrespro/pg_wait_sampling>

---

## Install

```ini
# postgresql.conf (restart required)
shared_preload_libraries = 'pg_stat_statements,pg_wait_sampling'
```

```sql
CREATE EXTENSION IF NOT EXISTS pg_wait_sampling;
```

!!! note
    Not every managed provider supports it — check the provider's extension list (it is not available on standard Amazon RDS; use Performance Insights / Database Insights there).

---

## Views & functions

| Object | Contents |
|---|---|
| `pg_wait_sampling_current` | Current wait event per backend |
| `pg_wait_sampling_history` | Ring buffer of recent samples (`pid, ts, event_type, event, queryid`) |
| `pg_wait_sampling_profile` | Cumulative counts per `pid, event_type, event, queryid` |
| `pg_wait_sampling_reset_profile()` | Reset the profile |

### Settings

| Setting | Default | Notes |
|---|---|---|
| `pg_wait_sampling.history_size` | 5000 | Ring buffer size |
| `pg_wait_sampling.history_period` | 10 ms | Sampling interval for history |
| `pg_wait_sampling.profile_period` | 10 ms | Sampling interval for profile |
| `pg_wait_sampling.profile_pid` | on | Profile per PID (off = aggregate across PIDs) |
| `pg_wait_sampling.profile_queries` | top | Collect `queryid` (needs `pg_stat_statements` / `compute_query_id`) |

---

## Useful queries

### Top wait events overall

```sql
SELECT event_type, event, sum(count) AS samples,
       round(100.0 * sum(count) / sum(sum(count)) OVER (), 2) AS pct
FROM pg_wait_sampling_profile
WHERE event IS NOT NULL
GROUP BY event_type, event
ORDER BY samples DESC
LIMIT 20;
```

### Top waits per query (join to pg_stat_statements)

```sql
SELECT p.event_type, p.event, sum(p.count) AS samples, left(s.query, 100) AS query
FROM pg_wait_sampling_profile p
JOIN pg_stat_statements s USING (queryid)
WHERE p.event IS NOT NULL
GROUP BY p.event_type, p.event, s.query
ORDER BY samples DESC
LIMIT 20;
```

Rows with `event IS NULL` are samples where the backend was on CPU.
