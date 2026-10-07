# Cluster directory structure

A **cluster** is one `$PGDATA` directory served by one postmaster, containing many databases.

| Path | Contents |
|---|---|
| `PG_VERSION` | Major version |
| `postgresql.conf`, `pg_hba.conf`, `pg_ident.conf`, `postgresql.auto.conf` | Config (`ALTER SYSTEM` writes the `.auto` file) |
| `postmaster.pid`, `postmaster.opts` | Running server PID / options |
| `global/` | Cluster-wide catalogs (`pg_database`, `pg_authid`, …) and **`global/pg_control`** |
| `base/<db_oid>/` | One directory per database, files named by relfilenode |
| `pg_wal/` | WAL segments (16 MB each by default) |
| `pg_xact/` | Commit status (clog) |
| `pg_subtrans/`, `pg_multixact/`, `pg_commit_ts/`, `pg_serial/`, `pg_notify/` | Other SLRU data |
| `pg_tblspc/` | Symlinks to tablespace locations |
| `pg_replslot/` | Replication slot state |
| `pg_logical/` | Logical decoding snapshots / mappings |
| `pg_twophase/` | Prepared transaction state files |
| `pg_stat/` | Cumulative stats saved at clean shutdown (PG15+ keeps them in shared memory while running) |
| `pg_dynshmem/`, `pg_snapshots/`, `pg_stat_tmp/` | Runtime scratch |

```sql
SELECT oid, datname FROM pg_database;                -- base/<oid>
SELECT pg_relation_filepath('public.orders');        -- base/16384/16422
SELECT pg_filenode_relation(0, 16422);               -- reverse lookup
SHOW data_directory;
```

## Tablespaces

A tablespace is just another directory: `pg_tblspc/<tablespace_oid>` → `/mnt/fast/PG_17_<catversion>/<db_oid>/<relfilenode>`.

```sql
CREATE TABLESPACE fast LOCATION '/mnt/fast';
ALTER TABLE orders SET TABLESPACE fast;   -- rewrites the table, ACCESS EXCLUSIVE lock
SELECT spcname, pg_tablespace_location(oid) FROM pg_tablespace;
```

## relfilenode vs OID

`pg_class.oid` is the permanent identity; `pg_class.relfilenode` is the *current file name*. Operations that rewrite a table assign a new relfilenode: `TRUNCATE`, `VACUUM FULL`, `CLUSTER`, `REINDEX`, `ALTER TABLE … SET TABLESPACE`, and rewriting `ALTER TABLE` (e.g. type change).
