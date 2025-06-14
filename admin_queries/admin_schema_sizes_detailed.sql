SELECT
    n.nspname AS schema_name,
    pg_size_pretty(SUM(pg_relation_size(c.oid))) AS main_table_size,
    pg_size_pretty(SUM(pg_indexes_size(c.oid))) AS index_size,
    pg_size_pretty(SUM(pg_total_relation_size(c.reltoastrelid))) AS toast_size,
    pg_size_pretty(SUM(pg_total_relation_size(c.oid))) AS combined_size
FROM
    pg_class c
JOIN
    pg_namespace n ON n.oid = c.relnamespace
WHERE
    c.relkind = 'r' -- Regular tables
    AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
GROUP BY
    n.nspname
ORDER BY
    SUM(pg_total_relation_size(c.oid)) DESC
LIMIT 10;


--  schema_name         | main_table_size | index_size | toast_size | combined_size
-- ---------------------+-----------------+------------+------------+---------------
--  data_gathering      | 919 MB          | 8496 kB    | 1239 MB    | 2167 MB
--  stats_cgmbet        | 884 MB          | 0 bytes    | 80 kB      | 885 MB
--  asp                 | 202 MB          | 32 kB      | 28 MB      | 230 MB
--  stats_football_data | 1832 kB         | 0 bytes    | 40 kB      | 1968 kB
--  stats_betfair       | 488 kB          | 184 kB     | 16 kB      | 752 kB
--  goals_mad           | 136 kB          | 88 kB      | 32 kB      | 360 kB
--  logs                | 40 kB           | 0 bytes    | 8192 bytes | 72 kB
--  stats_general       | 16 kB           | 16 kB      |            | 56 kB
--  public              | 8192 bytes      | 0 bytes    | 8192 bytes | 16 kB
-- (9 rows)