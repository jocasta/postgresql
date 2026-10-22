# pg_buffercache: Introduction

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** No
- **Docs:** <https://www.postgresql.org/docs/current/pgbuffercache.html>

## What it does

pg_buffercache exposes the contents of PostgreSQL's shared buffer cache (`shared_buffers`) as a view: one row per buffer,
showing which relation and block it holds, whether it's dirty, and its usage count. Aggregated, it answers questions like
"which tables and indexes are actually in memory?", "is `shared_buffers` big enough?" and "how much of the cache is dirty?".
PG16+ adds cheap summary functions (`pg_buffercache_summary()`, `pg_buffercache_usage_counts()`) and PG17+ can evict buffers for testing.

## How it's installed

Full procedure: [Install](install.md).

It's a contrib module — it ships in the PostgreSQL **contrib** package (`postgresql-contrib` on most distros; already included in the `postgresql-<ver>` package on Debian/Ubuntu and in the official Docker image), so there's nothing extra to download.
No preload or restart — just `CREATE EXTENSION pg_buffercache;` in the database you want to inspect.
Access is granted to the `pg_monitor` role by default.

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
