# TimescaleDB: Install

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
