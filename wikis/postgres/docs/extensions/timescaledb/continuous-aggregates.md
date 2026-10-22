# Continuous Aggregates

A materialized view over a hypertable that is **refreshed incrementally** — only buckets whose raw data
changed are recomputed.

---

## Create

```sql
CREATE MATERIALIZED VIEW IF NOT EXISTS metrics.cpu_hourly
WITH (timescaledb.continuous) AS
SELECT
  time_bucket(INTERVAL '1 hour', time) AS bucket,
  host,
  avg(usage_user) AS avg_usage_user,
  max(usage_user) AS max_usage_user,
  avg(usage_sys)  AS avg_usage_sys,
  max(usage_sys)  AS max_usage_sys
FROM metrics.cpu
GROUP BY bucket, host
WITH NO DATA;

GRANT SELECT ON metrics.cpu_hourly TO mike;
```

- The query must `GROUP BY` a `time_bucket(...)` on the hypertable's time column.
- Caggs can be built on other caggs (hierarchical: minute → hour → day).

---

## Refresh policy

```sql
-- Every 30 mins, refresh the window 3 days ago -> 1 hour ago
SELECT add_continuous_aggregate_policy(
  'metrics.cpu_hourly',
  start_offset      => INTERVAL '3 days',
  end_offset        => INTERVAL '1 hour',
  schedule_interval => INTERVAL '30 minutes',
  if_not_exists     => TRUE
);
```

| Parameter | Meaning |
|---|---|
| `start_offset` | How far back to look for changed data. Keep it **shorter than the raw table's retention**, or the refresh will wipe aggregates for dropped chunks. |
| `end_offset` | Don't materialize the most recent, still-changing buckets. At least one bucket width. |
| `schedule_interval` | How often the job runs. |

Manual refresh:

```sql
CALL refresh_continuous_aggregate('metrics.cpu_hourly', NULL, now() - INTERVAL '1 hour');
```

---

## Real-time aggregation

Since 2.13, caggs default to `materialized_only = true`: queries return only materialized buckets.
To union in not-yet-materialized raw data at query time:

```sql
ALTER MATERIALIZED VIEW metrics.cpu_hourly SET (timescaledb.materialized_only = false);
```

---

## Compression and retention on caggs

Caggs are stored in their own hypertable, so they can have their own (longer) retention — e.g. raw data 90 days, hourly rollups 2 years:

```sql
ALTER MATERIALIZED VIEW metrics.cpu_hourly SET (timescaledb.compress = true);
SELECT add_compression_policy('metrics.cpu_hourly', INTERVAL '30 days');
SELECT add_retention_policy('metrics.cpu_hourly', INTERVAL '2 years');
```

---

## Flyway / transactions

`CREATE MATERIALIZED VIEW ... WITH (timescaledb.continuous) ... WITH DATA` and
`CALL refresh_continuous_aggregate(...)` **cannot run inside a transaction**. Flyway wraps each migration in
one, so either:

- create with `WITH NO DATA` and let the policy fill it, or
- put the statement in its own migration with a sidecar config:

```
migrations/sql_test/V6__backfill_cpu_hourly.sql
migrations/sql_test/V6__backfill_cpu_hourly.sql.conf   ->  executeInTransaction=false
```
