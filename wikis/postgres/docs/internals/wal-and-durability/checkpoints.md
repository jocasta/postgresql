# Checkpoints

A **checkpoint** flushes all dirty buffers to disk and writes a checkpoint record, so recovery only needs WAL from the checkpoint's **REDO point** onward.

## Triggers

| Trigger | Setting / cause |
|---|---|
| Time | `checkpoint_timeout` (default 5 min) |
| WAL volume | `max_wal_size` (default 1 GB) — "requested" checkpoint |
| Manual | `CHECKPOINT` command |
| Other | Shutdown, end of recovery, `pg_backup_start()`, `CREATE DATABASE` |

## Spreading

`checkpoint_completion_target` (default 0.9) spreads the writes over 90% of the interval to avoid an I/O spike; the checkpointer then `fsync`s the files.

## pg_control

`global/pg_control` records the location of the latest checkpoint, cluster state (`in production`, `shut down`, `in crash recovery`), timeline and key settings. It's the first file read on startup.

```bash
pg_controldata $PGDATA | grep -E 'state|checkpoint location|REDO location|TimeLineID'
```

```sql
SELECT * FROM pg_control_checkpoint();

-- PG17+: timed vs requested checkpoints (many "requested" ⇒ raise max_wal_size)
SELECT num_timed, num_requested, write_time, sync_time, buffers_written
FROM pg_stat_checkpointer;
```

Set `log_checkpoints = on` (default since PG15). See also [Settings → Checkpoints](../../settings/checkpoints/checkpoints.md) and [Tuning Checkpoints For Heavy Write Load](../../settings/checkpoints/tuning-checkpoints-for-heavy-write-load.md).
