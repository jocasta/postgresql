# TimescaleDB

Time-series extension: turns a regular table into a **hypertable** that is automatically partitioned into time-based **chunks**, and adds compression (columnstore), retention, continuous aggregates and a built-in job scheduler.

- **Type:** third-party — not on RDS / Aurora; some managed providers only ship the Apache-2 edition (no compression / continuous aggregates)
- **Preload required:** Yes — `shared_preload_libraries = 'timescaledb'` (restart)
- **Repo:** <https://github.com/timescale/timescaledb>
- **Docs:** <https://docs.timescale.com/>
- **Local sandbox:** `docker/postgres_timescaledb_docker` in this repo (Flyway-managed, two databases)

| Page | Covers |
|---|---|
| [Hypertables](hypertables.md) | Creating hypertables, chunk sizing, indexes, inspecting chunks |
| [Compression & Retention](compression-retention.md) | Columnstore settings, compression and retention policies, background jobs |
| [Continuous Aggregates](continuous-aggregates.md) | Incrementally-refreshed rollups and their refresh policies |
| [Telegraf](telegraf/introduction.md) | Telegraf `outputs.postgresql` auto-creating hypertables |

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

## Install

```ini
# postgresql.conf — requires a restart. timescaledb should be listed first.
shared_preload_libraries = 'timescaledb,pg_stat_statements'
timescaledb.telemetry_level = off
timescaledb.max_background_workers = 8      # policy jobs: compression, retention, cagg refresh
max_worker_processes = 24                   # >= max_background_workers + max_parallel_workers
                                            #    + 1 (launcher) + 1 per database using timescaledb
max_locks_per_transaction = 256             # every chunk is a table - wide queries take many locks
```

```sql
CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public;

SELECT extname, extversion FROM pg_extension WHERE extname = 'timescaledb';
SELECT default_version FROM pg_available_extensions WHERE name = 'timescaledb';
```

!!! note
    The extension is created **per database**, but each database using it costs a background worker —
    size `max_worker_processes` accordingly.

!!! warning "Flyway / search_path"
    With `flyway.defaultSchema=flyway`, Flyway puts its own schema first in `search_path`.
    Use `WITH SCHEMA public` or the extension's functions land in the `flyway` schema.

---

## Upgrade

After installing a newer package (and restarting), update the extension in **each** database.
`ALTER EXTENSION timescaledb UPDATE` must be the **first statement in a fresh session**, so use `psql -X`
rather than a migration tool (Flyway runs its own queries on the connection first):

```bash
psql -X -h localhost -U mike_migrations -d test    -c "ALTER EXTENSION timescaledb UPDATE;"
psql -X -h localhost -U mike_migrations -d metrics -c "ALTER EXTENSION timescaledb UPDATE;"
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
