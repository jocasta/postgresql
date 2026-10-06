# pg_squeeze

Removes table bloat **online**, like [pg_repack](../pg-repack/index.md), but runs entirely inside the server: it uses **logical decoding** instead of triggers, and has a built-in scheduler so tables can be squeezed automatically.

- **Type:** third-party (CYBERTEC) — no client binary needed
- **Preload required:** **Yes**
- **Repo:** <https://github.com/cybertec-postgresql/pg_squeeze>

---

## Install

```ini
# postgresql.conf (restart required)
wal_level = logical
max_replication_slots = 10                   # pg_squeeze uses one slot per running squeeze
shared_preload_libraries = 'pg_squeeze'

# optional: start the scheduler workers automatically
squeeze.worker_autostart = 'appdb'           # space-separated list of databases
squeeze.worker_role = 'postgres'
```

```sql
CREATE EXTENSION IF NOT EXISTS pg_squeeze;   -- objects live in schema "squeeze"
```

---

## Squeeze a table now

```sql
-- squeeze_table(schema, table, clustering_index, rel_tablespace, ind_tablespaces)
SELECT squeeze.squeeze_table('public', 'orders');

-- also re-order rows by an index (online CLUSTER)
SELECT squeeze.squeeze_table('public', 'orders', 'orders_created_at_idx');

-- move the table to another tablespace while you're at it
SELECT squeeze.squeeze_table('public', 'orders', NULL, 'fast_ssd');
```

The call runs in your session and returns when the table has been swapped.

---

## Scheduled squeezing

Register tables in `squeeze.tables`. A scheduler worker checks them and only squeezes when bloat exceeds the threshold.

```sql
-- start the scheduler for this database (if not using worker_autostart)
SELECT squeeze.start_worker();

-- check public.orders at 22:30 on Wednesdays and Fridays
INSERT INTO squeeze.tables (tabschema, tabname, schedule, free_space_extra)
VALUES ('public', 'orders',
        ('{30}', '{22}', NULL, NULL, '{3, 5}'),  -- (minutes, hours, days_of_month, months, days_of_week)
        30);                                      -- squeeze if free space > fillfactor-adjusted + 30%
```

### `squeeze.tables` options

| Column | Default | Meaning |
|---|---|---|
| `schedule` | — | `(minutes, hours, days_of_month, months, days_of_week)` arrays; `NULL` = any |
| `free_space_extra` | 50 | % of free space above what fillfactor implies that triggers a squeeze |
| `min_size` | 8 MB | Skip tables smaller than this |
| `vacuum_max_age` | 1 hour | If last VACUUM is older than this, free-space stats are considered stale |
| `max_retry` | 0 | Retries after a failure |
| `clustering_index` | NULL | Index to order rows by |
| `rel_tablespace` / `ind_tablespaces` | NULL | Move table / indexes |
| `skip_analyze` | false | Skip `ANALYZE` afterwards |

---

## Monitoring

```sql
-- Completed squeezes
SELECT tabschema, tabname, started, finished, ins_initial, ins, upd, del
FROM squeeze.log
ORDER BY started DESC
LIMIT 20;

-- Failures
SELECT * FROM squeeze.errors ORDER BY occurred DESC LIMIT 20;

-- Running workers
SELECT * FROM squeeze.get_active_workers();
SELECT squeeze.stop_worker(<pid>);
```

---

## pg_squeeze vs pg_repack

| | pg_squeeze | pg_repack |
|---|---|---|
| Change capture | Logical decoding | Triggers + log table |
| Client binary | Not needed (SQL functions) | Required, version must match |
| Built-in scheduling | Yes (`squeeze.tables`) | No (use cron / pg_cron) |
| Needs `wal_level = logical` | **Yes** (restart) | No |
| Needs `shared_preload_libraries` | **Yes** (restart) | No |
| Index-only rebuild | No | Yes (`--only-indexes`) |
| Overhead on writes during run | Lower (no triggers) | Higher (trigger per row) |
| Managed DB availability | Limited — check your provider | Widely available (RDS, Aurora, …) |

---

## Requirements & gotchas

- Table needs a **primary key or a replica identity index**.
- Needs free disk ≈ the size of the table + indexes while the copy is built.
- An `ACCESS EXCLUSIVE` lock is taken briefly at the end to swap files; `squeeze.max_xlock_time` (ms) limits how long it may be held before giving up and retrying.
- Uses a replication slot while running — a stuck squeeze retains WAL, so watch `pg_replication_slots`.
- Generates WAL roughly the size of the table — watch replica lag.
- Don't run DDL on the table while it's being squeezed.

Measure bloat first with [pgstattuple](../pgstattuple/index.md).
