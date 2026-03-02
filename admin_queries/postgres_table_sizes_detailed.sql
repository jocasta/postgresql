
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
