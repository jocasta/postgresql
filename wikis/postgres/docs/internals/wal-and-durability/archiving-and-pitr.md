# WAL archiving and PITR

**Point-in-time recovery** = a base backup + every WAL segment since → replay to any moment.

```ini
# postgresql.conf
archive_mode = on                     # restart
archive_command = 'test ! -f /archive/%f && cp %p /archive/%f'
# or PG15+: archive_library = 'basic_archive' / a backup tool's module
archive_timeout = 60                  # force a segment switch at least every 60s
```

```sql
SELECT archived_count, last_archived_wal, last_archived_time,
       failed_count, last_failed_wal, last_failed_time
FROM pg_stat_archiver;
```

!!! warning
    If `archive_command` keeps failing, WAL is **never removed** from `pg_wal` — the disk fills and the server stops.

## Restoring to a point in time

```ini
# postgresql.conf on the restored base backup
restore_command = 'cp /archive/%f %p'
recovery_target_time = '2026-10-06 14:29:00+00'
recovery_target_action = 'promote'     # or pause
```

```bash
touch $PGDATA/recovery.signal    # PG12+: replaces recovery.conf
pg_ctl -D $PGDATA start
```

Each promotion starts a new **timeline** (first 8 hex digits of the segment name), with a `.history` file, so you can recover along alternate histories. Use a proper tool (pgBackRest, Barman, WAL-G) in production — see [Backups](../../backups/index.md).
