SELECT
    COALESCE(n.nspname, 'TOTAL') AS schema_name,
    pg_size_pretty(SUM(CASE WHEN c.relkind = 'r' THEN pg_relation_size(c.oid) ELSE 0 END)) AS main_table_size,
    pg_size_pretty(SUM(CASE WHEN c.relkind IN ('r', 'p') THEN pg_indexes_size(c.oid) ELSE 0 END)) AS index_size,
    pg_size_pretty(SUM(CASE WHEN c.relkind = 'm' THEN pg_total_relation_size(c.oid) ELSE 0 END)) AS materialized_view_size,
    pg_size_pretty(SUM(CASE WHEN c.relkind NOT IN ('r', 'p', 'i', 't', 'm') THEN pg_total_relation_size(c.oid) ELSE 0 END)) AS other_objects_size,
    pg_size_pretty(SUM(pg_total_relation_size(c.oid))) AS combined_size
FROM
    pg_class c
JOIN
    pg_namespace n ON n.oid = c.relnamespace
WHERE
    n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
GROUP BY
    ROLLUP(n.nspname)
ORDER BY
    SUM(pg_total_relation_size(c.oid)) DESC;


--         schema_name        | main_table_size | index_size | materialized_view_size | other_objects_size | combined_size 
-- ---------------------------+-----------------+------------+------------------------+--------------------+---------------
--  TOTAL                     | 374 GB          | 105 GB     | 69 GB                  | 1840 kB            | 682 GB
--  osmm_archiving            | 104 GB          | 15 GB      | 0 bytes                | 0 bytes            | 136 GB
--  pegareports               | 53 GB           | 27 GB      | 0 bytes                | 8192 bytes         | 106 GB
--  mapping                   | 32 GB           | 9831 MB    | 23 GB                  | 48 kB              | 82 GB
--  rosgis                    | 28 GB           | 4382 MB    | 36 GB                  | 304 kB             | 78 GB
--  lrs                       | 16 GB           | 8888 MB    | 0 bytes                | 24 kB              | 34 GB
--  charging_service          | 16 GB           | 6048 MB    | 0 bytes                | 0 bytes            | 28 GB
--  titles                    | 18 GB           | 3360 MB    | 0 bytes                | 0 bytes            | 26 GB
--  house_class               | 16 GB           | 4472 MB    | 0 bytes                | 16 kB              | 25 GB
--  abcore                    | 17 GB           | 3267 MB    | 0 bytes                | 0 bytes            | 24 GB
--  mis                       | 7147 MB         | 4041 MB    | 0 bytes                | 0 bytes            | 15 GB
--  abpremium                 | 7789 MB         | 2247 MB    | 0 bytes                | 144 kB             | 12 GB
--  inspire                   | 5766 MB         | 1298 MB    | 1521 MB                | 16 kB              | 11 GB
--  datateam                  | 6997 MB         | 81 MB      | 1641 MB                | 72 kB              | 10 GB


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