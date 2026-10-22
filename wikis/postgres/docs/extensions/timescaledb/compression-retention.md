# Compression & Retention

Both are run as **background jobs** by TimescaleDB's scheduler — no pg_cron needed.

---

## Compression (columnstore)

Older chunks are converted to a compressed columnar format. Typical savings are 90%+ and range scans over
compressed data are often faster.

```sql
ALTER TABLE metrics.cpu SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'host',
  timescaledb.compress_orderby   = 'time DESC'
);

-- Compress chunks older than 7 days
SELECT add_compression_policy('metrics.cpu', INTERVAL '7 days', if_not_exists => TRUE);
```

| Setting | Choose |
|---|---|
| `compress_segmentby` | Column(s) you filter / group by (`host`, `device_id`, `tag_id`). Medium cardinality — each value becomes its own compressed segment. |
| `compress_orderby` | Usually `time DESC`. Determines order within a segment. |

!!! note "Naming"
    From 2.18 these are also exposed as **columnstore** names (`timescaledb.enable_columnstore`,
    `timescaledb.segmentby`, `add_columnstore_policy`). The old names still work, and jobs show up as
    `Columnstore Policy [n]`.

Compressed chunks accept inserts and updates (2.11+), but they are slower than on uncompressed chunks —
set the policy interval so late-arriving data mostly lands in uncompressed chunks.

```sql
-- Manual
SELECT compress_chunk(c)   FROM show_chunks('metrics.cpu', older_than => INTERVAL '7 days') c;
SELECT decompress_chunk(c) FROM show_chunks('metrics.cpu', newer_than => INTERVAL '3 days') c;

-- Stats
SELECT * FROM hypertable_compression_stats('metrics.cpu');
```

---

## Retention

Drops whole chunks older than the interval — far cheaper than `DELETE`.

```sql
SELECT add_retention_policy('metrics.cpu', INTERVAL '90 days', if_not_exists => TRUE);

-- Manual
SELECT drop_chunks('metrics.cpu', older_than => INTERVAL '90 days');

-- Remove
SELECT remove_retention_policy('metrics.cpu');
```

!!! warning
    Retention drops raw data from the hypertable. A continuous aggregate built on it keeps its
    materialized rows unless its refresh window reaches back over the dropped range — keep the cagg's
    `start_offset` shorter than the retention interval. See [Continuous Aggregates](continuous-aggregates.md).

---

## Jobs

```sql
SELECT job_id, application_name, schedule_interval, hypertable_name, owner
FROM timescaledb_information.jobs;

SELECT job_id, last_run_status, last_run_started_at, next_start, total_failures
FROM timescaledb_information.job_stats;

-- Run a job now rather than waiting for its schedule
CALL run_job(<job_id>);

-- Pause / change a job
SELECT alter_job(<job_id>, scheduled => false);
SELECT alter_job(<job_id>, schedule_interval => INTERVAL '1 hour');
```

Jobs run as their **owner** (the role that added the policy), which must own the hypertable.
