# pg_stat_statements

Tracks planning and execution statistics for every normalised SQL statement. The single most useful extension for finding slow / expensive queries.

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** **Yes**
- **Docs:** <https://www.postgresql.org/docs/current/pgstatstatements.html>

---

## Install

```ini
# postgresql.conf (restart required)
shared_preload_libraries = 'pg_stat_statements'
compute_query_id = auto              # PG14+, default
pg_stat_statements.max = 10000       # distinct statements tracked
pg_stat_statements.track = top       # top | all | none
pg_stat_statements.track_utility = on
pg_stat_statements.track_planning = off  # on adds overhead
```

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

---

## Useful queries

### Top queries by total time

```sql
SELECT
    round(total_exec_time::numeric, 0)            AS total_ms,
    calls,
    round(mean_exec_time::numeric, 2)             AS mean_ms,
    round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 2) AS pct,
    rows,
    left(query, 120)                              AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

### Slowest on average (with enough calls to matter)

```sql
SELECT calls, round(mean_exec_time::numeric, 2) AS mean_ms,
       round(stddev_exec_time::numeric, 2) AS stddev_ms, left(query, 120) AS query
FROM pg_stat_statements
WHERE calls > 100
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### Worst cache hit ratio (most I/O)

```sql
SELECT calls,
       shared_blks_hit, shared_blks_read,
       round(100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0), 2) AS hit_pct,
       left(query, 120) AS query
FROM pg_stat_statements
ORDER BY shared_blks_read DESC
LIMIT 20;
```

### Temp file spillers (candidates for `work_mem`)

```sql
SELECT calls, temp_blks_written, left(query, 120) AS query
FROM pg_stat_statements
WHERE temp_blks_written > 0
ORDER BY temp_blks_written DESC
LIMIT 20;
```

### Reset

```sql
SELECT pg_stat_statements_reset();                 -- everything
SELECT pg_stat_statements_reset(0, 0, <queryid>);  -- one statement
SELECT stats_reset FROM pg_stat_statements_info;    -- PG14+: when last reset, and dealloc count
```

---

## Gotchas

- Column names changed in PG13: `total_time` → `total_exec_time` (+ `total_plan_time`). In PG17, `blk_read_time` → `shared_blk_read_time`.
- Stats are cumulative since the last reset — snapshot and diff for time windows.
- If `pg_stat_statements_info.dealloc` keeps rising, raise `pg_stat_statements.max`.
- Query text is normalised: literals become `$1`, `$2`…
