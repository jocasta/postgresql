# Direct I/O and async I/O (PG17 / PG18)

## PG16: direct I/O (developer option)

`debug_io_direct = 'data, wal'` bypasses the OS cache with `O_DIRECT`. It's a **testing** option only — without async I/O and read-ahead it's slow. It exists to prepare for the AIO work.

## PG17: streaming I/O

- A new **read stream** API lets sequential scans, `ANALYZE` and `pg_prewarm` issue larger, combined reads.
- `io_combine_limit` (default 128 kB) — how many adjacent blocks are read in one system call.

## PG18: asynchronous I/O

| Setting | Values | Notes |
|---|---|---|
| `io_method` | `worker` (default), `io_uring` (Linux), `sync` | `sync` = old behaviour |
| `io_workers` | default 3 | I/O worker processes for `io_method = worker` |
| `effective_io_concurrency` | default 16 (was 1) | How far ahead reads are issued |
| `maintenance_io_concurrency` | default 16 | Same, for maintenance work |

- Backends issue reads **ahead of need** and keep working while I/O completes — big gains for sequential scans, bitmap heap scans and VACUUM, especially on cloud block storage with high latency.
- Writes still go through the existing (synchronous) paths in PG18.
- New view `pg_aios` shows in-flight async I/Os.

```sql
SHOW io_method;
SELECT * FROM pg_aios;   -- PG18+
```
