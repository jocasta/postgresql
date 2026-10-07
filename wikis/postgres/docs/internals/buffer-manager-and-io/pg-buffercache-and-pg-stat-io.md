# pg_buffercache and pg_stat_io

The two main windows into the buffer manager.

## pg_buffercache — *what* is cached

```sql
CREATE EXTENSION IF NOT EXISTS pg_buffercache;

SELECT c.relname,
       count(*) AS buffers,
       pg_size_pretty(count(*) * 8192) AS cached,
       round(avg(b.usagecount), 2) AS avg_usage,
       count(*) FILTER (WHERE b.isdirty) AS dirty
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
WHERE b.reldatabase = (SELECT oid FROM pg_database WHERE datname = current_database())
GROUP BY c.relname
ORDER BY buffers DESC LIMIT 15;
```

More queries: [pg_buffercache extension page](../../extensions/pg-buffercache/index.md).

## pg_stat_io — *how* I/O happens (PG16+)

One row per `backend_type` × `object` (relation, temp relation, wal in PG18) × `context` (normal, vacuum, bulkread, bulkwrite, init):

| Column | Meaning |
|---|---|
| `reads`, `read_bytes`* | Blocks read into buffers (from OS cache or disk) |
| `writes`, `write_bytes`* | Dirty blocks written out |
| `extends` | Relation extended (new blocks) |
| `hits` | Found in shared buffers |
| `evictions` | Buffer evicted to make room |
| `reuses` | Ring buffer slot reused |
| `fsyncs` | fsync calls |
| `*_time` | With `track_io_timing = on` |

\* `*_bytes` columns replaced `op_bytes` in PG18.

```sql
SELECT backend_type, object, context,
       reads, hits, writes, evictions, fsyncs,
       round(100.0 * hits / nullif(hits + reads, 0), 2) AS hit_pct
FROM pg_stat_io
WHERE reads + writes + coalesce(hits, 0) > 0
ORDER BY reads + writes DESC;

SELECT pg_stat_reset_shared('io');
```

Red flags: high `writes` / `fsyncs` for `client backend` (bgwriter/checkpointer not keeping up), high `evictions` in `normal` context (`shared_buffers` too small for the working set).
