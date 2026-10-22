# TimescaleDB: Introduction

- **Type:** third-party — not on RDS / Aurora; some managed providers only ship the Apache-2 edition (no compression / continuous aggregates)
- **Preload required:** Yes — `shared_preload_libraries = 'timescaledb'` (restart)
- **Repo:** <https://github.com/timescale/timescaledb>
- **Docs:** <https://docs.timescale.com/>
- **Local sandbox:** `docker/postgres_timescaledb_docker` in this repo (Flyway-managed, two databases)

## What it does

TimescaleDB is a time-series extension. It turns a regular table into a **hypertable** that is automatically partitioned
into time-based **chunks**, so inserts stay fast and old data can be dropped a chunk at a time. On top of that it adds
native **compression** (columnstore — often 90%+ space savings), **retention** policies, **continuous aggregates**
(incrementally-refreshed materialised rollups), time-series SQL functions such as `time_bucket()`, and a built-in background
job scheduler that runs those policies. Ideal for metrics, IoT, events and monitoring data.

## How it's installed

Full procedure: [Install](install.md).

Third-party — add Timescale's apt/yum repository and install `timescaledb-2-postgresql-<ver>`
(see `docker/postgres_timescaledb_docker` in this repo), or use the `timescale/timescaledb` Docker image.
It **must** be first in `shared_preload_libraries` (restart required); optionally run `timescaledb-tune` to size memory and
worker settings. Then `CREATE EXTENSION timescaledb;` in each database that uses it. Not available on RDS / Aurora.

---

## Licensing / editions

| Edition | Includes |
|---|---|
| Apache 2 | Hypertables, chunks, `time_bucket` |
| Community (Timescale License, TSL) | + compression / columnstore, continuous aggregates, policies, jobs |

The packages from the Timescale apt/yum repo include the TSL features. Check what you have:

```sql
SHOW timescaledb.license;   -- 'timescale' (TSL) or 'apache'
```

---

## Useful views

```sql
SELECT * FROM timescaledb_information.hypertables;
SELECT * FROM timescaledb_information.chunks;
SELECT * FROM timescaledb_information.jobs;
SELECT * FROM timescaledb_information.job_stats;
SELECT * FROM timescaledb_information.continuous_aggregates;
```

---

## TimescaleDB vs pg_partman

Both give you time-partitioned tables; see also [pg_partman](../pg-partman/index.md).

| | TimescaleDB | pg_partman |
|---|---|---|
| Partitioning | Hypertable chunks, created automatically on insert | Native declarative partitions, pre-created by maintenance |
| Maintenance | Built-in job scheduler | `run_maintenance_proc()` via pg_cron or BGW |
| Compression | Native columnstore (often 90%+) | None (TOAST only) |
| Rollups | Continuous aggregates | Roll your own (materialized views / pg_cron) |
| Managed availability | Limited (not RDS / Aurora) | Widely available |
