# pg_stat_statements: Introduction

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** **Yes**
- **Docs:** <https://www.postgresql.org/docs/current/pgstatstatements.html>

## What it does

pg_stat_statements tracks planning and execution statistics for every SQL statement the server runs. Queries are
**normalised** (literals replaced with `$1`, `$2`, …) so all executions of the same query shape are aggregated into one row
with call count, total / mean / max time, rows, shared-buffer hits and reads, temp file usage and WAL generated.
It's the single most useful extension for finding slow or expensive queries, and most other tooling
(pg_wait_sampling, pganalyze, Datadog, PMM, …) joins to it via `queryid`.

## How it's installed

Full procedure: [Install](install.md).

It's a contrib module — it ships in the PostgreSQL **contrib** package (`postgresql-contrib` on most distros; already included in the `postgresql-<ver>` package on Debian/Ubuntu and in the official Docker image), so there's nothing extra to download.
Because it uses shared memory it **must** be added to `shared_preload_libraries` (restart required), then enabled with
`CREATE EXTENSION pg_stat_statements;` in any database you want to query the view from (stats are collected cluster-wide).
On RDS / Aurora it's preloaded by default.

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
