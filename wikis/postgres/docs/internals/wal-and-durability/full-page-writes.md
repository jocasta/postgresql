# Full-page writes and torn pages

- PostgreSQL pages are 8 KB but the OS/disk may only write 4 KB (or 512 B) atomically. A crash mid-write can leave a **torn page** — half old, half new — which WAL redo can't fix because redo assumes a consistent page.
- With `full_page_writes = on` (default), the **first modification of each page after a checkpoint** logs a **full-page image (FPI)** of the whole page. Recovery restores the image first, then replays later records.
- FPIs often dominate WAL volume right after each checkpoint, so **longer checkpoint intervals reduce WAL**.
- With data checksums (default in `initdb` from PG18) or `wal_log_hints = on`, hint-bit changes also trigger FPIs.

```sql
-- How much WAL is full-page images?
SELECT wal_records, wal_fpi,
       round(100.0 * wal_fpi / nullif(wal_records, 0), 1) AS fpi_pct_of_records,
       pg_size_pretty(wal_bytes) AS wal_bytes
FROM pg_stat_wal;
```

!!! danger
    Never set `full_page_writes = off` unless the filesystem guarantees atomic 8 KB writes (e.g. ZFS). It saves WAL but risks unrecoverable corruption after a crash.
