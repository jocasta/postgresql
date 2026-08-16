# Sizes

## Admin Schema Relation Sizes

``` sql title="admin_schema_relation_sizes.sql"
CREATE OR REPLACE FUNCTION public.admin_schema_relation_sizes(p_schema text DEFAULT NULL)
RETURNS TABLE (
    schema_name text,
    relname text,
    reltype text,
    total_size_mb bigint,
    total_size_gb numeric,
    total_size_pretty text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        nspname::text AS schema_name, 
        relname, 
        CASE
            WHEN relkind = 'r' THEN 'table'
            WHEN relkind = 'i' THEN 'index'
            WHEN relkind = 'S' THEN 'sequence'
            WHEN relkind = 'v' THEN 'view'
            WHEN relkind = 'm' THEN 'materialized view'
            WHEN relkind = 'c' THEN 'composite type'
            WHEN relkind = 't' THEN 'TOAST table'
            ELSE 'other'
        END AS reltype,
        pg_total_relation_size(pg_class.oid) / (1024 * 1024) AS total_size_mb,
        pg_total_relation_size(pg_class.oid) / (1024 * 1024 * 1024) AS total_size_gb,
        pg_size_pretty(pg_total_relation_size(pg_class.oid)) AS total_size_pretty
    FROM 
        pg_class
    JOIN 
        pg_namespace ON pg_namespace.oid = pg_class.relnamespace
    WHERE 
        p_schema IS NULL OR nspname = p_schema
    ORDER BY 
        nspname, relname;
END;
$$ LANGUAGE plpgsql;
```

## Admin Schema Sizes

``` sql title="admin_schema_sizes.sql"
CREATE OR REPLACE FUNCTION public.admin_schema_sizes(p_schema text DEFAULT NULL)
RETURNS TABLE (
    schema_name text,
    total_size bigint,
    total_size_pretty text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        nspname::text AS schema_name,
        SUM(pg_total_relation_size(pg_class.oid))::bigint AS total_size,
        pg_size_pretty(SUM(pg_total_relation_size(pg_class.oid))) AS total_size_pretty
    FROM 
        pg_class
    JOIN 
        pg_namespace ON pg_namespace.oid = pg_class.relnamespace
    WHERE 
        p_schema IS NULL OR nspname = p_schema
    GROUP BY 
        nspname;
END;
$$ LANGUAGE plpgsql;


--       schema_name      | total_size | total_size_pretty 
-- -----------------------+------------+-------------------
--  public                | 3858669568 | 3680 MB
--  pg_catalog            |   13033472 | 12 MB
--  migration_test_schema | 7892803584 | 7527 MB
--  python_commvault_test |      57344 | 56 kB
--  pg_toast              |    1458176 | 1424 kB
--  information_schema    |     253952 | 248 kB
```

## Admin Schema Sizes Detailed

``` sql title="admin_schema_sizes_detailed.sql"
WITH base AS (
    SELECT
        n.nspname,
        c.oid,
        c.relkind,
        c.reltoastrelid
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
),
table_stats AS (
    SELECT
        nspname,
        oid,
        relkind,

        -- heap only
        pg_relation_size(oid) AS heap_bytes,

        -- indexes owned by this table/matview
        pg_indexes_size(oid) AS index_bytes,

        -- actual toast table size (if exists)
        CASE
            WHEN reltoastrelid <> 0
            THEN pg_total_relation_size(reltoastrelid)
            ELSE 0
        END AS toast_bytes

    FROM base
    WHERE relkind IN ('r','p','m')
),
other_objects AS (
    SELECT
        nspname,
        SUM(pg_total_relation_size(oid)) AS other_bytes
    FROM base
    WHERE relkind NOT IN ('r','p','m','i','t')
    GROUP BY nspname
)
SELECT
    COALESCE(t.nspname, 'TOTAL') AS schema_name,

    pg_size_pretty(SUM(heap_bytes)) AS table_size,

    pg_size_pretty(SUM(index_bytes)) AS index_size,

    pg_size_pretty(SUM(toast_bytes)) AS toast_size,

    pg_size_pretty(
        SUM(CASE WHEN relkind = 'm' THEN heap_bytes ELSE 0 END)
    ) AS mat_view_size,

    pg_size_pretty(COALESCE(SUM(o.other_bytes),0)) AS other_objects,

    pg_size_pretty(
        SUM(heap_bytes) +
        SUM(index_bytes) +
        SUM(toast_bytes) +
        COALESCE(SUM(o.other_bytes),0)
    ) AS combined_size

FROM table_stats t
LEFT JOIN other_objects o
    ON o.nspname = t.nspname
GROUP BY ROLLUP(t.nspname)
ORDER BY
    SUM(heap_bytes) +
    SUM(index_bytes) +
    SUM(toast_bytes) +
    COALESCE(SUM(o.other_bytes),0) DESC;


--  schema_name | table_size | index_size | toast_size | mat_view_size | other_objects | combined_size 
-- -------------+------------+------------+------------+---------------+---------------+---------------
--  TOTAL       | 436 GB     | 150 GB     | 17 GB      | 141 MB        | 5024 kB       | 603 GB
--  dms         | 355 GB     | 121 GB     | 4384 MB    | 0 bytes       | 1120 kB       | 481 GB
--  lr_spatial  | 46 GB      | 27 GB      | 2324 MB    | 141 MB        | 3584 kB       | 75 GB
--  auditing    | 35 GB      | 1197 MB    | 11 GB      | 0 bytes       | 288 kB        | 47 GB
--  public      | 6896 kB    | 208 kB     | 8192 bytes | 0 bytes       | 0 bytes       | 7112 kB
--  reporting   | 368 kB     | 736 kB     | 16 kB      | 0 bytes       | 32 kB         | 1152 kB
--  _flyway     | 24 kB      | 32 kB      | 8192 bytes | 0 bytes       | 0 bytes       | 64 kB

-- Abbreviation	    Relkind Type
--      r	        regular table
--      i	        index
--      S	        sequence
--      t	        TOAST table
--      v	        view
--      m	        materialized view
--      c	        composite type
--      f	        foreign table
--      p	        partitioned table
--      I	        partitioned index
--      e	        external table
--      s	        special
--      T	        temporary table
--      x	        logical replication set
--      w	        write-ahead log (WAL)
--      d	        domain
--      b	        database
--      n	        namespace
--      a	        aggregate
--      P	        procedure
```

## Admin Table Sizes Detailed

``` sql title="admin_table_sizes_detailed.sql"
-- Break down table, index, toast & combined size

SELECT
    n.nspname AS schema_name,
    c.relname AS relation_name,

    c.relkind AS relkind,
    CASE c.relkind
        WHEN 'r' THEN 'regular table'
        WHEN 'p' THEN 'partitioned table'
        WHEN 'i' THEN 'index'
        WHEN 'I' THEN 'partitioned index'
        WHEN 'S' THEN 'sequence'
        WHEN 't' THEN 'TOAST table'
        WHEN 'v' THEN 'view'
        WHEN 'm' THEN 'materialized view'
        WHEN 'c' THEN 'composite type'
        WHEN 'f' THEN 'foreign table'
        WHEN 's' THEN 'special'
        ELSE 'unknown'
    END AS relkind_name,

    pg_size_pretty(pg_relation_size(c.oid)) AS main_relation_size, -- heap for tables/matviews; 0 for some relkinds
    pg_size_pretty(pg_indexes_size(c.oid)) AS index_size,
    COALESCE(pg_size_pretty(pg_total_relation_size(c_toast.oid)), '0 bytes') AS toast_size,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS combined_size
FROM
    pg_class c
JOIN
    pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN
    pg_class c_toast ON c.reltoastrelid = c_toast.oid
WHERE
    n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY
    pg_total_relation_size(c.oid) DESC
LIMIT 10;



--    schema_name    | relation_name | relkind | relkind_name  | main_relation_size | index_size | toast_size | combined_size 
-- ------------------+---------------+---------+---------------+--------------------+------------+------------+---------------
--  lrs_extract      | audit_log     | r       | regular table | 19 GB              | 25 GB      | 0 bytes    | 44 GB
--  lrs_extract_beta | audit_log     | r       | regular table | 19 GB              | 25 GB      | 0 bytes    | 44 GB
--  lrs_extract      | case_notes    | r       | regular table | 15 GB              | 4998 MB    | 8192 bytes | 20 GB
--  lrs_extract_beta | case_notes    | r       | regular table | 15 GB              | 4998 MB    | 8192 bytes | 20 GB
--  lrs_extract      | ap_people     | r       | regular table | 13 GB              | 1702 MB    | 8192 bytes | 14 GB
--  lrs_extract_beta | ap_people     | r       | regular table | 13 GB              | 1702 MB    | 8192 bytes | 14 GB
--  lrs_extract      | tt_cdebtor    | r       | regular table | 13 GB              | 1052 MB    | 8192 bytes | 14 GB
--  lrs_extract_beta | tt_cdebtor    | r       | regular table | 13 GB              | 1051 MB    | 8192 bytes | 14 GB
--  lrs_extract      | tt_bpeople    | r       | regular table | 12 GB              | 1102 MB    | 8192 bytes | 14 GB
--  lrs_extract_beta | tt_bpeople    | r       | regular table | 12 GB              | 1102 MB    | 8192 bytes | 14 GB
```

## Postgres Average Row Size

``` sql title="postgres_average_row_size.sql"
WITH table_size AS (
    SELECT
        c.relname AS table_name,
        pg_table_size(c.oid) AS main_table_size,
        pg_total_relation_size(c.oid) AS total_size,
        pg_total_relation_size(c.oid) - pg_table_size(c.oid) AS toast_size
    FROM pg_class c
    WHERE c.relname in ('packaged_events','media')
    AND c.relkind = 'r'
),
row_count AS (
    SELECT
        relname AS table_name,
        n_live_tup AS row_count
    FROM pg_stat_user_tables
    WHERE relname in ('packaged_events','media')
)
SELECT
    ts.table_name,
    ts.main_table_size,
    ts.toast_size,
    ts.total_size,
    COALESCE(rc.row_count, 1) AS row_count,
    (ts.total_size / NULLIF(rc.row_count, 0)) AS avg_row_size
FROM table_size ts
LEFT JOIN row_count rc ON ts.table_name = rc.table_name;
```
