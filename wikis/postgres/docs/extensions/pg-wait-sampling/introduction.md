# pg_wait_sampling: Introduction

- **Type:** third-party (Postgres Professional)
- **Preload required:** **Yes**
- **Repo:** <https://github.com/postgrespro/pg_wait_sampling>

## What it does

pg_wait_sampling runs a background collector that samples the wait event of every backend many times a second and keeps
both a rolling **history** and an aggregated **profile** per process and per `queryid`. Where `pg_stat_activity` only shows
a single instantaneous snapshot, this answers "over the last hour, what have sessions actually spent their time waiting on —
locks, I/O, LWLocks, client?" and, joined to pg_stat_statements, *which queries* are doing the waiting.

## How it's installed

Full procedure: [Install](install.md).

Third-party (Postgres Professional) — install the OS package `postgresql-<ver>-pg-wait-sampling`
(PGDG apt) or `pg_wait_sampling_<ver>` (PGDG yum), or build from source with `make USE_PGXS=1 install`.
It **must** be in `shared_preload_libraries` (restart required), then run `CREATE EXTENSION pg_wait_sampling;`.
Not available on standard Amazon RDS / Aurora.

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
