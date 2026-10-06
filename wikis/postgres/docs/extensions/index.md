# Extensions

## Extension Overview

| Extension | Category | Needs `shared_preload_libraries`? | Ships with core (contrib)? |
|---|---|---|---|
| [PostGIS](postgis/index.md) | Data type / geospatial | No | No |
| [pgvector](pgvector/index.md) | Data type / vector search | No | No |
| [pg_stat_statements](pg-stat-statements/index.md) | Observability | Yes | Yes |
| [auto_explain](auto-explain/index.md) | Observability | Yes (or `LOAD` per session) | Yes |
| [pg_buffercache](pg-buffercache/index.md) | Observability | No | Yes |
| [pgstattuple](pgstattuple/index.md) | Observability / bloat | No | Yes |
| [pg_wait_sampling](pg-wait-sampling/index.md) | Observability | Yes | No |
| [btree_gin](btree-gin/index.md) | Indexing | No | Yes |
| [btree_gist](btree-gist/index.md) | Indexing / constraints | No | Yes |
| [pg_cron](pg-cron/index.md) | Scheduling | Yes | No |
| [pg_partman](pg-partman/index.md) | Partitioning | Only for the background worker | No |
| [pg_repack](pg-repack/index.md) | Maintenance / bloat | No | No |
| [pg_squeeze](pg-squeeze/index.md) | Maintenance / bloat | Yes (+ `wal_level = logical`) | No |
| [pg_prewarm](pg-prewarm/index.md) | Cache warming | Only for autoprewarm | Yes |
| [postgres_fdw](postgres-fdw/index.md) | Federation | No | Yes |

---

## Common Commands

### What's available / installed?

```sql
-- Extensions available to install on this server
SELECT name, default_version, installed_version, comment
FROM pg_available_extensions
ORDER BY name;

-- Extensions installed in the current database
SELECT e.extname, e.extversion, n.nspname AS schema
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
ORDER BY e.extname;
```

### Install / upgrade / remove

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_partman SCHEMA partman;

ALTER EXTENSION pg_stat_statements UPDATE;          -- to default_version
ALTER EXTENSION pg_stat_statements UPDATE TO '1.11'; -- to a specific version

DROP EXTENSION pg_stat_statements;
```

### Preloaded libraries

```sql
SHOW shared_preload_libraries;
```

```ini
# postgresql.conf — requires a restart
shared_preload_libraries = 'pg_stat_statements,auto_explain,pg_cron'
```

!!! note
    Extensions are installed **per database** (`CREATE EXTENSION` must be run in each database that needs it),
    but `shared_preload_libraries` is **per cluster**. On RDS / Aurora, set it in the DB parameter group and reboot.
