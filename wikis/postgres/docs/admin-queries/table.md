# Table

## Postgres Check Table Reloptions

``` sql title="postgres_check_table_reloptions.sql"
SELECT
    oid,
    s.schemaname,
    oid::regclass table_name,
    substr(unnest(reloptions), 1, strpos(unnest(reloptions), '=') - 1) option,
    substr(unnest(reloptions), 1 + strpos(unnest(reloptions), '=')) value
FROM
    pg_class c
    JOIN pg_stat_all_tables s ON (s.relid = c.oid)
WHERE
    reloptions IS NOT NULL
    AND (s.schemaname,s.relname) IN (
        SELECT
            t.table_schema,
            t.table_name
        FROM
            information_schema.tables t
            JOIN pg_catalog.pg_class c ON (t.table_name = c.relname)
            JOIN pg_catalog.pg_user u ON (c.relowner = u.usesysid)
        WHERE
            t.table_schema LIKE '%'
            AND u.usename LIKE '%'
            AND t.table_name LIKE '%'
            AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
);
```

## Postgres Table Cache Hit Rate

``` sql title="postgres_table_cache_hit_rate.sql"
SELECT
    sum(heap_blks_read) AS heap_read,
    sum(heap_blks_hit) AS heap_hit,
    (sum(heap_blks_hit) - sum(heap_blks_read)) / sum(heap_blks_hit) AS ratio
FROM
    pg_statio_user_tables;
```

## Postgres Table Cache Hit Vs Disk Hit Ratio

``` sql title="postgres_table_cache_hit_vs_disk_hit_ratio.sql"
WITH all_tables AS (
    SELECT
        *
    FROM (
        SELECT
            'all'::text AS table_name,
            sum((coalesce(heap_blks_read, 0) + coalesce(idx_blks_read, 0) + coalesce(toast_blks_read, 0) + coalesce(tidx_blks_read, 0))) AS from_disk,
        sum((coalesce(heap_blks_hit, 0) + coalesce(idx_blks_hit, 0) + coalesce(toast_blks_hit, 0) + coalesce(tidx_blks_hit, 0))) AS from_cache
    FROM
        pg_statio_all_tables --> change to pg_statio_USER_tables if you want to check only user tables (excluding postgres's own tables)
) a
    WHERE (from_disk + from_cache) > 0 -- discard tables without hits
),
tables AS (
    SELECT
        *
    FROM (
        SELECT
            relname AS table_name,
            ((coalesce(heap_blks_read, 0) + coalesce(idx_blks_read, 0) + coalesce(toast_blks_read, 0) + coalesce(tidx_blks_read, 0))) AS from_disk,
        ((coalesce(heap_blks_hit, 0) + coalesce(idx_blks_hit, 0) + coalesce(toast_blks_hit, 0) + coalesce(tidx_blks_hit, 0))) AS from_cache
    FROM
        pg_statio_all_tables --> change to pg_statio_USER_tables if you want to check only user tables (excluding postgres's own tables)
) a
    WHERE (from_disk + from_cache) > 0 -- discard tables without hits
)
SELECT
    table_name AS "table name",
    from_disk AS "disk hits",
    round((from_disk::numeric / (from_disk + from_cache)::numeric) * 100.0, 2) AS "% disk hits",
    round((from_cache::numeric / (from_disk + from_cache)::numeric) * 100.0, 2) AS "% cache hits",
    (from_disk + from_cache) AS "total hits"
FROM (
    SELECT
        *
    FROM
        all_tables
    UNION ALL
    SELECT
        *
    FROM
        tables) a
ORDER BY
    (
        CASE WHEN table_name = 'all' THEN
            0
        ELSE
            1
        END),
    from_disk DESC;
```

## Postgres Table Constraint Info

``` sql title="postgres_table_constraint_info.sql"
SELECT
    tc.table_schema,
    tc.table_name,
    pgc.contype,
    string_agg(col.column_name, ', ') AS columns,
    tc.constraint_name,
    tc.enforced,
    pgc.convalidated
FROM
    information_schema.table_constraints tc
    JOIN pg_namespace nsp ON nsp.nspname = tc.constraint_schema
    JOIN pg_constraint pgc ON pgc.conname = tc.constraint_name
        AND pgc.connamespace = nsp.oid
        AND pgc.contype IN ('c', 'p', 'f')
    JOIN information_schema.columns col ON col.table_schema = tc.table_schema
        AND col.table_name = tc.table_name
        AND col.ordinal_position = ANY (pgc.conkey)
WHERE
    tc.constraint_schema NOT IN ('pg_catalog', 'information_schema')
GROUP BY
    tc.table_schema,
    tc.table_name,
    tc.constraint_name,
    pgc.contype,
    tc.enforced,
    pgc.convalidated
ORDER BY
    tc.table_schema,
    tc.table_name;
```

## Postgres Table Full User Table Count

``` sql title="postgres_table_full_user_table_count.sql"
-- THIS CAN BE HEAVY ON A LARGE DATABASE

SELECT
    ns.nspname  AS schemaname,
    cls.relname AS tablename,
    cnt.row_count
FROM
    pg_class cls
JOIN
    pg_namespace ns
    ON ns.oid = cls.relnamespace
JOIN LATERAL (
    SELECT COUNT(*) AS row_count
    FROM pg_catalog.pg_class c2 -- dummy alias placeholder
    JOIN LATERAL EXECUTE FORMAT('SELECT COUNT(*) FROM %I.%I', ns.nspname, cls.relname)
) cnt ON true
WHERE
    cls.relkind = 'r'  -- ordinary tables
    AND ns.nspname = 'flyway'
ORDER BY
    ns.nspname ;
```

## Postgres Table Index Used Pct

``` sql title="postgres_table_index_used_pct.sql"
SELECT
    relname,
    100 * idx_scan / (seq_scan + idx_scan) percent_of_times_index_used,
    n_live_tup rows_in_table
FROM
    pg_stat_user_tables
WHERE (seq_scan + idx_scan) > 0
ORDER BY
    n_live_tup DESC;
```

## Postgres Table Reloptions

``` sql title="postgres_table_reloptions.sql"
SELECT
    oid,
    s.schemaname,
    oid::regclass table_name,
    substr(unnest(reloptions), 1, strpos(unnest(reloptions), '=') - 1) option,
    substr(unnest(reloptions), 1 + strpos(unnest(reloptions), '=')) value
FROM
    pg_class c
    JOIN pg_stat_all_tables s ON (s.relid = c.oid)
WHERE
    reloptions IS NOT NULL
    AND (s.schemaname,
        s.relname) IN (
        SELECT
            t.table_schema,
            t.table_name
        FROM
            information_schema.tables t
            JOIN pg_catalog.pg_class c ON (t.table_name = c.relname)
            JOIN pg_catalog.pg_user u ON (c.relowner = u.usesysid)
        WHERE
            t.table_schema LIKE '%'
            AND u.usename LIKE '%'
            AND t.table_name LIKE '%'
            AND t.table_schema NOT IN ('information_schema', 'pg_catalog'));
```

## Postgres Table Sizes Detailed

``` sql title="postgres_table_sizes_detailed.sql"
-- Break down estimated_rows, table, index, toast & combined size

SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    c.reltuples::bigint AS estimated_rows,
    pg_size_pretty(pg_relation_size(c.oid)) AS main_table_size,
    pg_size_pretty(pg_indexes_size(c.oid)) AS index_size,
    COALESCE(pg_size_pretty(pg_total_relation_size(c_toast.oid)), '0 bytes') AS toast_size,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS combined_size
FROM
    pg_class c
LEFT JOIN
    pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN
    pg_class c_toast ON c.reltoastrelid = c_toast.oid
WHERE
    c.relkind = 'r'
    AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY
    pg_total_relation_size(c.oid) DESC
LIMIT 30;




-- ┌─────────────────┬────────────────────────────────────┬────────────────┬─────────────────┬────────────┬────────────┬───────────────┐
-- │   schema_name   │             table_name             │ estimated_rows │ main_table_size │ index_size │ toast_size │ combined_size │
-- ├─────────────────┼────────────────────────────────────┼────────────────┼─────────────────┼────────────┼────────────┼───────────────┤
-- │ data_gathering  │ ou_3_5_backup_07_02_2026           │        1201046 │ 583 MB          │ 30 MB      │ 7212 MB    │ 7825 MB       │
-- │ data_gathering  │ ou_3_5_backup_13_07_2025_09_38     │         331420 │ 141 MB          │ 0 bytes    │ 2082 MB    │ 2224 MB       │
-- │ data_gathering  │ market_full_extract_test           │        3543161 │ 463 MB          │ 0 bytes    │ 8192 bytes │ 463 MB        │
-- │ data_gathering  │ ou_3_5                             │          57984 │ 23 MB           │ 2352 kB    │ 429 MB     │ 455 MB        │
-- │ asp             │ stored_values                      │         265733 │ 194 MB          │ 0 bytes    │ 28 MB      │ 221 MB        │
```

## Postgres Table Stats Status

``` sql title="postgres_table_stats_status.sql"
WITH table_stats AS (
    SELECT
        schemaname,
        tablename,
        count(1) AS stats_count
    FROM
        pg_stats
    WHERE
        schemaname LIKE '%'
    GROUP BY
        schemaname,
        tablename
)
SELECT
    pt.schemaname AS schema_name,
    pt.tablename AS table_name,
    CASE WHEN pi.inhparent::text IS NULL THEN
        NULL
    ELSE
        pi.inhparent::regclass
    END AS top_table_name,
    pc.reltuples::numeric AS est_num_live_rows,
    ps.n_live_tup AS rows_in_stats,
    ps.n_tup_ins AS tot_num_inserts,
    ps.n_tup_upd AS tot_num_updates,
    ps.n_tup_del AS tot_num_deletes,
    ps.n_mod_since_analyze AS modified_rows,
    CASE WHEN pc.reltuples::numeric < 0 THEN
        100.00
    WHEN (ps.n_tup_ins + ps.n_tup_upd + ps.n_tup_del) = 0 THEN
        0.00
    WHEN ps.n_mod_since_analyze::numeric > 0
        AND pc.reltuples::numeric > 0 THEN
        CASE WHEN (ROUND((ps.n_mod_since_analyze / pc.reltuples)::numeric, 2) * 100) > 100 THEN
            100
        ELSE
            ROUND((ps.n_mod_since_analyze / pc.reltuples)::numeric, 2) * 100
        END
    WHEN ps.n_mod_since_analyze::numeric > 0
        AND pc.reltuples::numeric = 0 THEN
        ROUND((ps.n_mod_since_analyze / 1)::numeric, 2) * 100
    WHEN pc.reltuples = 0
        AND ps.n_live_tup = 0
        AND ps.n_mod_since_analyze = 0 THEN
        0.00
    ELSE
        ROUND((ps.n_live_tup / pc.reltuples)::numeric - 1, 2)
    END AS percent_stale,
    CASE WHEN ps.last_analyze IS NULL
        AND ps.last_autoanalyze IS NOT NULL THEN
        'Auto - ' || TO_CHAR(ps.last_autoanalyze, 'DD-MON-YY HH24:MI')
    WHEN ps.last_analyze IS NULL
        AND ts.stats_count IS NULL
        AND ps.last_autoanalyze IS NULL THEN
        'No Stats Available'
    WHEN ps.last_analyze IS NULL
        AND ts.stats_count > 0
        AND ps.last_autoanalyze IS NULL THEN
        'pg_stats - Status Unknown'
    WHEN ps.last_analyze IS NULL
        AND pc.reltuples > 0
        AND ps.last_autoanalyze IS NULL THEN
        'pg_class - Status Unknown'
    WHEN ps.last_analyze IS NOT NULL
        AND ps.last_autoanalyze IS NOT NULL
        AND (ps.last_autoanalyze > ps.last_analyze) THEN
        'Auto - ' || TO_CHAR(ps.last_autoanalyze, 'DD-MON-YY HH24:MI')
    ELSE
        'Manual - ' || TO_CHAR(ps.last_analyze, 'DD-MON-YY HH24:MI')
    END AS last_analyzed,
    CASE WHEN ps.last_vacuum IS NULL
        AND ps.last_autovacuum IS NOT NULL THEN
        'Auto - ' || TO_CHAR(ps.last_autovacuum, 'DD-MON-YY HH24:MI')
    WHEN ps.last_vacuum IS NOT NULL
        AND ps.last_autovacuum IS NULL THEN
        'Manual - ' || TO_CHAR(ps.last_vacuum, 'DD-MON-YY HH24:MI')
    WHEN ps.last_vacuum > ps.last_autovacuum THEN
        'Manual - ' || TO_CHAR(ps.last_vacuum, 'DD-MON-YY HH24:MI')
    ELSE
        'Auto - ' || TO_CHAR(ps.last_autovacuum, 'DD-MON-YY HH24:MI')
    END AS vacuum_status
FROM
    pg_tables pt
    JOIN pg_stat_all_tables ps ON ps.schemaname = pt.schemaname
        AND ps.relname = pt.tablename
    JOIN pg_class pc ON ps.relid = pc.oid
    LEFT JOIN pg_catalog.pg_inherits pi ON ps.relid = pi.inhrelid
    LEFT JOIN table_stats ts ON ts.schemaname = pt.schemaname
        AND ts.tablename = pt.tablename
WHERE
    pt.tablename LIKE '%'
ORDER BY
    3 NULLS LAST,
    1,
    2;
```
