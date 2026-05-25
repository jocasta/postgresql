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