# pgstattuple: Introduction

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** No
- **Docs:** <https://www.postgresql.org/docs/current/pgstattuple.html>

## What it does

pgstattuple reports tuple-level statistics for tables and indexes by physically scanning them: live and dead tuple counts
and sizes, free space, and — for B-tree indexes — leaf density and fragmentation. It's the *exact* way to measure bloat,
rather than the estimates from `pg_stat_user_tables` or catalog-based bloat queries, and helps decide whether a table needs
`VACUUM`, `pg_repack` / `pg_squeeze`, or an index needs `REINDEX`. `pgstattuple_approx()` gives a cheaper estimate using the visibility map.

## How it's installed

Full procedure: [Install](install.md).

It's a contrib module — it ships in the PostgreSQL **contrib** package (`postgresql-contrib` on most distros; already included in the `postgresql-<ver>` package on Debian/Ubuntu and in the official Docker image), so there's nothing extra to download.
No preload or restart — run `CREATE EXTENSION pgstattuple;`. Non-superusers need membership of `pg_stat_scan_tables`.
Beware that the full functions read the whole relation, so run them off-peak on large tables.

---

## Functions

| Function | What it does | Cost |
|---|---|---|
| `pgstattuple(regclass)` | Live/dead tuple counts and free space for a table | **Full scan** |
| `pgstattuple_approx(regclass)` | Estimates using the visibility map — skips all-visible pages | Much cheaper |
| `pgstatindex(regclass)` | B-tree index density, leaf fragmentation | Full index scan |
| `pgstatginindex(regclass)` | GIN pending list info | Cheap |
| `pgstathashindex(regclass)` | Hash index stats | Full index scan |
| `pg_relpages(regclass)` | Page count | Cheap |

---

## Examples

### Table bloat

```sql
SELECT
    pg_size_pretty(table_len)  AS table_size,
    tuple_percent,
    dead_tuple_percent,
    free_percent
FROM pgstattuple('public.orders');

-- cheaper estimate for large tables
SELECT * FROM pgstattuple_approx('public.orders');
```

High `dead_tuple_percent` → vacuum isn't keeping up. High `free_percent` → space reclaimable only by a rewrite (`VACUUM FULL`, [pg_repack](../pg-repack/index.md)).

### Index bloat

```sql
SELECT
    pg_size_pretty(index_size) AS index_size,
    avg_leaf_density,          -- ~90 is healthy for a fresh B-tree (fillfactor 90)
    leaf_fragmentation
FROM pgstatindex('public.orders_pkey');
```

`avg_leaf_density` well below ~50–60% → candidate for `REINDEX CONCURRENTLY`.

### Check all indexes on a table

```sql
SELECT i.indexrelid::regclass AS index,
       s.avg_leaf_density, s.leaf_fragmentation,
       pg_size_pretty(s.index_size) AS size
FROM pg_index i
JOIN pg_class ic ON ic.oid = i.indexrelid
JOIN pg_am am    ON am.oid = ic.relam
CROSS JOIN LATERAL pgstatindex(i.indexrelid) s
WHERE i.indrelid = 'public.orders'::regclass
  AND am.amname = 'btree';
```

---

## Gotchas

- `pgstattuple` and `pgstatindex` read every page — run off-peak on big relations, or use `pgstattuple_approx`.
- For a fleet-wide estimate without scanning, use the catalog-based bloat queries in [Admin Queries → Bloat](../../admin-queries/bloat.md).
