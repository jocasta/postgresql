# Local (per-backend) memory

| Setting | Default | Used for | Notes |
|---|---|---|---|
| `work_mem` | 4 MB | Each sort, hash, materialise node | **Per node, per backend, per parallel worker** — one query can use many multiples |
| `hash_mem_multiplier` | 2.0 (PG15+) | Hash tables get `work_mem × multiplier` | |
| `maintenance_work_mem` | 64 MB | `CREATE INDEX`, `VACUUM`, `ALTER TABLE ADD FK` | PG17+ vacuum no longer capped at 1 GB for dead TIDs |
| `autovacuum_work_mem` | -1 (use `maintenance_work_mem`) | Each autovacuum worker | |
| `temp_buffers` | 8 MB | Temporary tables (local buffers, not shared) | |
| `logical_decoding_work_mem` | 64 MB | Per walsender before spilling to disk | |

Memory inside a backend is managed with hierarchical **memory contexts** (`TopMemoryContext`, `CacheMemoryContext`, `MessageContext`, per-query `ExecutorState`…), freed in bulk when the context is reset.

```sql
-- Current session's memory contexts (PG14+)
SELECT name, parent, pg_size_pretty(total_bytes) AS total
FROM pg_backend_memory_contexts
ORDER BY total_bytes DESC
LIMIT 10;

-- Dump another backend's contexts to the server log
SELECT pg_log_backend_memory_contexts(12345);

-- Did sorts/hashes spill to disk?
SELECT datname, temp_files, pg_size_pretty(temp_bytes) FROM pg_stat_database;
```

Set `log_temp_files = 0` to log every spill, and see `EXPLAIN (ANALYZE)` output like `Sort Method: external merge  Disk: 51200kB`.
