# postgres_timescaledb_docker

Local Docker Postgres with the [TimescaleDB](https://docs.timescale.com/) extension, managed with Flyway. Follows the same pattern as `../postgres_flyway_docker`.

The container is built with TimescaleDB **installed and preloaded** (`shared_preload_libraries` in `postgresql.conf`), but the extension is **not created** in any database until you run `flyway migrate` — migration `V1` runs `CREATE EXTENSION timescaledb`. This keeps the extension (and its version) under migration control, the same way it would be on a managed database.

Two databases, each with its own Flyway migration stream (same pattern as the `test` / `postgres` streams in `../postgres_flyway_docker`):

| Database | Flyway config | Migrations | Purpose |
|---|---|---|---|
| `test` | `flyway.conf` | `migrations/sql_test/` | Sample hand-built hypertable, policies and continuous aggregate |
| `metrics` | `flyway_metrics.conf` | `migrations/sql_metrics/` | Telegraf `outputs.postgresql` target — Telegraf auto-creates its own hypertables |

Each stream keeps its history in a `flyway` schema within its own database.

---

## Prerequisites

- Docker
- [Flyway CLI](https://flywaydb.org/documentation/usage/commandline/) installed and on your `PATH`

---

## Usage

### 1. Start the Postgres container

```bash
./postgres_start_container.sh
```

This script:
- Builds `local-postgres-timescaledb:${PG_VERSION}` from `postgres:${PG_VERSION}` plus the `timescaledb-2-postgresql-${PG_MAJOR}` package from the Timescale apt repo
- Starts a container named `postgres18_6_tsdb` on port `5432` with `./postgresql.conf` mounted
- Mounts a named volume (`pg18_tsdb_data`) for data and `./logs` for PostgreSQL logs
- Creates the roles `mike_migrations` (superuser, used by Flyway), `mike` (app user) and `telegraf` (Telegraf writer, password `secret`)
- Creates the `metrics` database (owned by `mike_migrations`) — `CREATE DATABASE` can't run inside a Flyway migration
- Confirms `timescaledb` is preloaded, and reports whether the extension has been created yet:

```
[INFO] timescaledb preloaded: yes (available version 2.x.x)
[INFO] timescaledb extension: NOT created yet in 'test' - waiting for 'flyway migrate'
[INFO] timescaledb extension: NOT created yet in 'metrics' - waiting for 'flyway migrate'
```

The container configuration (version, port, credentials, etc.) is controlled by `.postgres.env`.

> Uses the same host port (5432) as the other docker folders — stop those containers first.

### 2. Run Flyway migrations

```bash
flyway migrate
flyway info
```

| Migration | What it does |
|---|---|
| `V1__Enable_Extension_timescaledb.sql` | `CREATE EXTENSION timescaledb WITH SCHEMA public` |
| `V2__initialise_metrics_schema.sql` | `metrics` schema + grants / default privileges for `mike` |
| `V3__create_hypertable_cpu.sql` | `metrics.cpu` hypertable (1 day chunks) |
| `V4__compression_and_retention_policies.sql` | Compress chunks > 7 days, drop chunks > 90 days |
| `V5__continuous_aggregate_cpu_hourly.sql` | `metrics.cpu_hourly` continuous aggregate + refresh policy |

Then the `metrics` database:

```bash
flyway -configFiles=flyway_metrics.conf migrate
flyway -configFiles=flyway_metrics.conf info
```

| Migration | What it does |
|---|---|
| `V1__Enable_Extension_timescaledb.sql` | `CREATE EXTENSION timescaledb WITH SCHEMA public` |
| `V2__initialise_telegraf_schema.sql` | `telegraf` schema owned by `telegraf`, read-only default privileges for `mike` |

### 3. Connect

```bash
psql -h localhost -p 5432 -U mike -d test
```

```bash
psql -h localhost -p 5432 -U mike -d metrics
```

See `Example_Commands` for loading sample data and inspecting chunks, jobs and compression.

---

## Telegraf (`metrics` database)

Tables in `metrics` are **not** created by migrations. Telegraf's `outputs.postgresql` plugin creates a table per measurement the first time it sees it, running `create_templates` to turn it into a hypertable with compression and retention policies:

```toml
[[outputs.postgresql]]
  connection = "host=localhost port=5432 user=telegraf password=secret dbname=metrics sslmode=disable"
  schema = "telegraf"
  tags_as_foreign_keys = true

  create_templates = [
    '''CREATE TABLE {{ .table }} ({{ .columns }})''',
    '''SELECT create_hypertable({{ .table|quoteLiteral }}, 'time', chunk_time_interval => INTERVAL '1 day')''',
    '''ALTER TABLE {{ .table }} SET (timescaledb.compress, timescaledb.compress_segmentby = 'tag_id')''',
    '''SELECT add_compression_policy({{ .table|quoteLiteral }}, INTERVAL '7 days')''',
    '''SELECT add_retention_policy({{ .table|quoteLiteral }}, INTERVAL '90 days')'''
  ]
```

How the migrations support that:

- **`telegraf` owns the `telegraf` schema** — so it can `CREATE TABLE` there, and as owner of each table it can call `create_hypertable`, set compression and add policies without being a superuser. The policy background jobs run as `telegraf`.
- **timescaledb lives in `public`** — the templates call `create_hypertable()` etc. unqualified, and `public` is on Telegraf's default `search_path`.
- **`mike` gets `SELECT`** on every table Telegraf creates, via `ALTER DEFAULT PRIVILEGES FOR ROLE telegraf`.
- With `tags_as_foreign_keys = true`, each measurement gets a metric hypertable (`telegraf.cpu`) plus a plain tag table (`telegraf.cpu_tag`). Tag tables use `tag_table_create_templates`, not `create_templates`, so they stay ordinary tables — which is why `compress_segmentby = 'tag_id'` works.
- Anything you want managed in `metrics` that Telegraf doesn't create (continuous aggregates over Telegraf tables, extra roles/grants) goes in `migrations/sql_metrics/`. A cagg over a Telegraf table can only be migrated once Telegraf has created that table.

### 4. Stop or destroy the container

```bash
./postgres_stop_container.sh      # stop, keep data volume
./postgres_destroy_container.sh   # remove container, volume, logs and local image
```

---

## TimescaleDB settings (`postgresql.conf`)

| Setting | Value | Why |
|---|---|---|
| `shared_preload_libraries` | `'timescaledb,pg_stat_statements'` | Required — timescaledb must be preloaded before `CREATE EXTENSION` |
| `timescaledb.telemetry_level` | `off` | No telemetry from dev containers |
| `timescaledb.max_background_workers` | `8` | Workers for policy jobs (compression, retention, cagg refresh) |
| `max_worker_processes` | `24` | Must be ≥ `timescaledb.max_background_workers` + `max_parallel_workers` + 1 + number of TimescaleDB databases |
| `max_parallel_workers` | `8` | |
| `max_locks_per_transaction` | `256` | Every chunk is a table — queries over many chunks take many locks |

Memory/WAL settings are sized modestly for a dev container.

---

## Writing Migrations

Same rules as `postgres_flyway_docker`: `V{version}__{description}.sql` in `migrations/sql_test/` (or `migrations/sql_metrics/` for the `metrics` database), never edit an applied migration.

TimescaleDB-specific notes:

- **Flyway's `search_path`** — with `flyway.defaultSchema=flyway`, Flyway puts the `flyway` schema first in `search_path`. That's why `V1` uses `WITH SCHEMA public`, and why tables are always schema-qualified.
- **Non-transactional statements** — Flyway runs each migration in a transaction. `CREATE MATERIALIZED VIEW ... WITH (timescaledb.continuous) ... WITH DATA` and `CALL refresh_continuous_aggregate(...)` cannot run in a transaction. Either use `WITH NO DATA` (as `V5` does) or add a sidecar file next to the migration:

  ```
  migrations/sql_test/V6__backfill_cpu_hourly.sql
  migrations/sql_test/V6__backfill_cpu_hourly.sql.conf   ->  executeInTransaction=false
  ```

- **Upgrading TimescaleDB** — after rebuilding the image with a newer package, `ALTER EXTENSION timescaledb UPDATE;` must be the first statement in a fresh session. Flyway runs its own queries on the connection first, so do this with `psql -X -h localhost -U mike_migrations -d test -c "ALTER EXTENSION timescaledb UPDATE;"` rather than in a migration. Repeat with `-d metrics`.

---

## Local Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `PG_VERSION` | `18.6` | Postgres version (base image tag) |
| `CONTAINER_NAME` | `postgres18_6_tsdb` | Docker container name |
| `HOST_PORT` | `5432` | Port exposed on localhost |
| `DATA_VOLUME` | `pg18_tsdb_data` | Named Docker volume for data |
| `DB_USER` | `mike` | Superuser for container management |
| `DB_PASSWORD` | `jocasta` | Superuser password |
| `DB_NAME` | `test` | Database created on init (and where timescaledb is created) |
