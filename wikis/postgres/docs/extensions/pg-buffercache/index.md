# pg_buffercache

Inspect what's in `shared_buffers` right now — which relations are cached, how much, and how "hot".

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** No
- **Docs:** <https://www.postgresql.org/docs/current/pgbuffercache.html>

---

## Install

```sql
CREATE EXTENSION IF NOT EXISTS pg_buffercache;
```

---

## Useful queries

### Top relations in shared_buffers (current database)

```sql
SELECT
    c.relname,
    c.relkind,
    pg_size_pretty(count(*) * current_setting('block_size')::int) AS buffered,
    round(100.0 * count(*) / (SELECT setting::int FROM pg_settings WHERE name = 'shared_buffers'), 2) AS pct_of_cache,
    round(100.0 * count(*) * current_setting('block_size')::int / nullif(pg_relation_size(c.oid), 0), 2) AS pct_of_rel_cached
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
WHERE b.reldatabase = (SELECT oid FROM pg_database WHERE datname = current_database())
GROUP BY c.oid, c.relname, c.relkind
ORDER BY count(*) DESC
LIMIT 20;
```

### Usage count distribution (is the cache under pressure?)

```sql
SELECT usagecount, count(*) AS buffers, sum(count(*)) OVER () AS total
FROM pg_buffercache
GROUP BY usagecount
ORDER BY usagecount;
```

Lots of buffers at usagecount 4–5 → working set fits comfortably. Mostly 0–1 → heavy churn, consider more `shared_buffers`.

### Summary (PG16+, cheap — no buffer locks)

```sql
SELECT * FROM pg_buffercache_summary();       -- used / unused / dirty / pinned / avg usagecount
SELECT * FROM pg_buffercache_usage_counts();  -- per usagecount bucket
```

### Dirty buffers per relation

```sql
SELECT c.relname, count(*) FILTER (WHERE b.isdirty) AS dirty, count(*) AS total
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.relname
ORDER BY dirty DESC
LIMIT 20;
```

---

## Gotchas

- Scanning the full `pg_buffercache` view on large `shared_buffers` is not free — avoid running it in tight loops.
- Only shows PostgreSQL's cache, not the OS page cache.
- PG17 adds `pg_buffercache_evict(bufferid)` for testing — superuser only, don't use in production.
