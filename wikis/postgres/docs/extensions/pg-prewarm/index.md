# pg_prewarm

Loads relation data into the buffer cache (or OS cache) on demand, and — with *autoprewarm* — restores `shared_buffers` contents automatically after a restart.

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** Only for autoprewarm
- **Docs:** <https://www.postgresql.org/docs/current/pgprewarm.html>

---

## Install

```sql
CREATE EXTENSION IF NOT EXISTS pg_prewarm;
```

---

## Manual prewarm

```sql
-- pg_prewarm(regclass, mode, fork, first_block, last_block) → blocks loaded
SELECT pg_prewarm('public.orders');                    -- default mode 'buffer'
SELECT pg_prewarm('public.orders_pkey');
SELECT pg_prewarm('public.orders', 'prefetch');        -- async OS read-ahead
SELECT pg_prewarm('public.orders', 'read');            -- sync read into OS cache
```

| Mode | Loads into | Notes |
|---|---|---|
| `buffer` | `shared_buffers` | Default; evicts other buffers if the relation doesn't fit |
| `read` | OS page cache | Synchronous |
| `prefetch` | OS page cache | Asynchronous; needs `posix_fadvise` support |

### Prewarm all indexes of a table

```sql
SELECT indexrelid::regclass, pg_prewarm(indexrelid)
FROM pg_index
WHERE indrelid = 'public.orders'::regclass;
```

---

## Autoprewarm

Periodically dumps the list of cached blocks to `$PGDATA/autoprewarm.blocks` and reloads them on startup.

```ini
# postgresql.conf (restart required)
shared_preload_libraries = 'pg_prewarm'
pg_prewarm.autoprewarm = on              # default on once preloaded
pg_prewarm.autoprewarm_interval = 300s   # 0 = dump only at shutdown
```

```sql
SELECT autoprewarm_dump_now();     -- force a dump
SELECT autoprewarm_start_worker(); -- start the worker if not preloaded at startup
```

---

## Gotchas

- Useful after failovers / restarts / major upgrades to avoid a cold-cache latency spike.
- Prewarming something larger than `shared_buffers` just evicts what you loaded first.
- Check the result with [pg_buffercache](../pg-buffercache/index.md).
- On Aurora, the cluster cache management feature / survivable page cache covers much of this.
