# Ring buffers

Large one-off operations would otherwise flush the whole cache. Instead they use a small private **ring** of buffers (a "buffer access strategy") and reuse them in a loop:

| Strategy | Used by | Ring size |
|---|---|---|
| `BULKREAD` | Sequential scans of tables larger than ¼ of `shared_buffers` | 256 KB |
| `VACUUM` | VACUUM / autovacuum, ANALYZE | `vacuum_buffer_usage_limit` (PG16+; 256 KB, 2 MB default since PG17) |
| `BULKWRITE` | `COPY FROM`, `CREATE TABLE AS`, `CREATE MATERIALIZED VIEW`, `ALTER TABLE` rewrite | 16 MB |

Effects:

- A big seq scan doesn't evict your hot working set — but also doesn't leave the table cached, so repeated full scans keep reading from the OS cache / disk.
- With a tiny ring, a backend doing bulk writes must write and fsync its own dirty buffers (and flush WAL) frequently.

```sql
VACUUM (BUFFER_USAGE_LIMIT '16MB') big_table;   -- PG16+: bigger ring = faster vacuum
SELECT backend_type, context, reads, writes, reuses
FROM pg_stat_io WHERE context IN ('bulkread', 'bulkwrite', 'vacuum') AND reads > 0;
```
