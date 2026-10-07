# OS page cache and double buffering

Until PG18's async I/O, PostgreSQL has relied on **buffered I/O**: reads and writes go through the kernel page cache.

- A page can be cached **twice** — in `shared_buffers` and in the OS cache ("double buffering").
- That's why `shared_buffers` is usually ~25% of RAM rather than 80%: the OS cache holds the rest, and a `shared_buffers` miss is often an OS cache hit (fast `read()`, no disk).
- `effective_cache_size` (planner hint only, allocates nothing) should be ~ `shared_buffers` + expected OS cache, e.g. 50–75% of RAM.
- The kernel also handles read-ahead for sequential scans and write-back of dirtied pages; the checkpointer's `fsync` forces durability.
- Linux tuning: avoid swapping (`vm.swappiness` low), cap dirty page cache (`vm.dirty_background_bytes`) to prevent fsync storms, use huge pages for `shared_buffers`.

```sql
-- Shared buffer hit ratio per database (OS cache hits count as "reads" here)
SELECT datname, blks_hit, blks_read,
       round(100.0 * blks_hit / nullif(blks_hit + blks_read, 0), 2) AS hit_pct
FROM pg_stat_database WHERE datname IS NOT NULL;
```
