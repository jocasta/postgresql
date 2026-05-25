
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
