# Hypertables

A hypertable looks like one table but is stored as many child tables (**chunks**), each covering a time range.
Inserts are routed to the right chunk, and new chunks are created automatically.

---

## Create

Create a plain table, then convert it:

```sql
CREATE TABLE IF NOT EXISTS metrics.cpu (
  time        TIMESTAMPTZ      NOT NULL,
  host        TEXT             NOT NULL,
  usage_user  DOUBLE PRECISION,
  usage_sys   DOUBLE PRECISION
);

SELECT create_hypertable(
  'metrics.cpu',
  by_range('time', INTERVAL '1 day'),
  if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS cpu_host_time_idx ON metrics.cpu (host, time DESC);
```

!!! note "Old vs new API"
    `by_range(...)` is the 2.13+ form. The older
    `create_hypertable('metrics.cpu', 'time', chunk_time_interval => INTERVAL '1 day')`
    still works but is deprecated.

`create_hypertable` creates an index on `(time DESC)` by default.

---

## Rules

- The time column must be `NOT NULL`.
- Any **unique index / primary key must include the time column** (uniqueness is enforced per chunk).
- Convert an existing table with data using `migrate_data => true` (locks the table — slow on big tables).

---

## Chunk sizing

Rule of thumb: the **most recent chunk(s), including their indexes, should fit in ~25% of memory**
(`shared_buffers`-ish), so inserts and recent queries stay in cache.

| Ingest rate | Starting point |
|---|---|
| Low (dev, small metrics) | `7 days` (default) |
| Moderate | `1 day` |
| Very high | `1 hour` – `6 hours` |

```sql
-- Affects new chunks only
SELECT set_chunk_time_interval('metrics.cpu', INTERVAL '6 hours');
```

Too many tiny chunks hurts planning time and lock usage (`max_locks_per_transaction`); too few huge chunks
hurts cache efficiency and makes retention coarse.

---

## Inspect

```sql
SELECT * FROM timescaledb_information.hypertables;

SELECT chunk_name, range_start, range_end, is_compressed
FROM timescaledb_information.chunks
WHERE hypertable_name = 'cpu'
ORDER BY range_start;

SELECT * FROM hypertable_detailed_size('metrics.cpu');
SELECT * FROM chunks_detailed_size('metrics.cpu') ORDER BY chunk_name;
```

---

## Sample data

```sql
INSERT INTO metrics.cpu (time, host, usage_user, usage_sys)
SELECT t, 'host-' || h, random() * 100, random() * 20
FROM generate_series(now() - INTERVAL '14 days', now(), INTERVAL '1 minute') AS t,
     generate_series(1, 5) AS h;
```

---

## time_bucket

`date_trunc` for arbitrary intervals:

```sql
SELECT time_bucket(INTERVAL '15 minutes', time) AS bucket,
       host,
       avg(usage_user)
FROM metrics.cpu
WHERE time > now() - INTERVAL '1 day'
GROUP BY bucket, host
ORDER BY bucket DESC;
```
