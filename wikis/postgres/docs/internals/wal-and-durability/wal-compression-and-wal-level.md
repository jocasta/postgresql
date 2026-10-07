# WAL compression and wal_level

## wal_compression

Compresses **full-page images** only (not ordinary records):

| Value | Notes |
|---|---|
| `off` | Default |
| `on` / `pglz` | Built-in, CPU-heavier |
| `lz4` | PG15+, fast — good default choice |
| `zstd` | PG15+, best ratio |

Often cuts WAL volume substantially on write-heavy systems with frequent checkpoints, at a small CPU cost.

## wal_level

| Level | Logs enough for | Notes |
|---|---|---|
| `minimal` | Crash recovery only | Skips WAL for some bulk ops (e.g. `COPY` into a table created in the same transaction); no archiving or replication (`max_wal_senders = 0`) |
| `replica` (default) | Archiving, physical streaming replication, hot standby | |
| `logical` | Everything in `replica` + logical decoding | Extra info for `REPLICA IDENTITY`; needed for logical replication, CDC, pg_squeeze |

Changing `wal_level` requires a restart.
