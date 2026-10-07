# synchronous_commit and group commit

| `synchronous_commit` | Commit returns after… | Risk on crash |
|---|---|---|
| `off` | WAL written to WAL buffers only | Lose up to ~3 × `wal_writer_delay` (≈600 ms) of **committed** transactions — but **no corruption** |
| `local` | WAL flushed locally | None locally; standby may lag |
| `remote_write` | Local flush + standby **received and written** (OS cache) | Standby OS crash could lose it |
| `on` (default) | Local flush + standby **flushed to disk** (if sync standbys configured) | None |
| `remote_apply` | …and standby has **replayed** it (read-your-writes on replica) | None |

Without `synchronous_standby_names`, `remote_*` and `on` all behave like `local`. It can be set per transaction:

```sql
SET LOCAL synchronous_commit = off;   -- e.g. for a low-value logging insert
```

## Group commit

WAL flushing is serialised by `WALWriteLock`; when one backend flushes, it flushes **everything** in the WAL buffers up to that point, so concurrent committers piggy-back on one `fsync`. `commit_delay` (µs) + `commit_siblings` can make a committer wait briefly to batch more — rarely needed, measure with `pg_test_fsync` first.

See also: [Settings → Synchronous Commit](../../settings/synchronous-commit.md).
