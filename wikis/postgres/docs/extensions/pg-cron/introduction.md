# pg_cron: Introduction

- **Type:** third-party (Citus Data / Microsoft) — available on RDS, Aurora, Azure, Cloud SQL
- **Preload required:** **Yes**
- **Repo:** <https://github.com/citusdata/pg_cron>

## What it does

pg_cron is a cron-style job scheduler that runs **inside** PostgreSQL as a background worker. Jobs are SQL commands scheduled
with standard cron syntax (or `'30 seconds'` intervals) via `cron.schedule()`, and run history is recorded in
`cron.job_run_details`. It's typically used for in-database housekeeping — `VACUUM` / `ANALYZE`, partition maintenance
(`partman.run_maintenance_proc()`), refreshing materialised views, purging old rows, taking stats snapshots — without
needing an external cron host, and it fails over with the database.

## How it's installed

Full procedure: [Install](install.md).

Third-party (Citus Data / Microsoft) — install the OS package `postgresql-<ver>-cron` (PGDG apt;
see `docker/postgres_flyway_docker` in this repo) or `pg_cron_<ver>` (PGDG yum). It's available on RDS, Aurora, Azure and Cloud SQL.
It **must** be in `shared_preload_libraries` with `cron.database_name` set (restart required), then run
`CREATE EXTENSION pg_cron;` **in that one database** — jobs can still target other databases via `cron.schedule_in_database()`.

---

## Scheduling jobs

```sql
-- name, schedule, command
SELECT cron.schedule('nightly-vacuum', '0 3 * * *', 'VACUUM ANALYZE public.orders');

-- every 30 seconds (pg_cron 1.5+)
SELECT cron.schedule('heartbeat', '30 seconds', $$INSERT INTO heartbeat VALUES (now())$$);

-- run in a different database than cron.database_name
SELECT cron.schedule_in_database('partman-maint', '@hourly',
                                 $$CALL partman.run_maintenance_proc()$$, 'appdb');

-- change / remove
SELECT cron.alter_job(job_id := 3, schedule := '0 4 * * *');
SELECT cron.unschedule('nightly-vacuum');
```

Schedule syntax is standard cron (`min hour dom month dow`), plus `@hourly`, `@daily`, `$` for last day of month, and `'N seconds'`.

---

## Monitoring

```sql
-- Defined jobs
SELECT jobid, jobname, schedule, database, username, active, command
FROM cron.job
ORDER BY jobid;

-- Recent runs / failures
SELECT jobid, status, return_message, start_time, end_time - start_time AS duration
FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 50;

SELECT * FROM cron.job_run_details WHERE status = 'failed' ORDER BY start_time DESC;
```

### Housekeeping — job_run_details grows forever

```sql
SELECT cron.schedule('purge-cron-history', '0 0 * * *',
    $$DELETE FROM cron.job_run_details WHERE end_time < now() - interval '7 days'$$);
-- or disable logging entirely: cron.log_run = off
```

---

## Gotchas

- Jobs run as the user that scheduled them; with libpq mode that user needs to be able to connect (check `pg_hba.conf`).
- A job won't start again while its previous run is still going — overlapping runs are queued, not parallel.
- `cron.max_running_jobs` (default 32) caps concurrent jobs and consumes connections.
- On a replica, jobs don't run (pg_cron only runs on the primary).
