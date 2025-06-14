
-- Break down table, index, toast & combined size

SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    pg_size_pretty(pg_relation_size(c.oid)) AS main_table_size, -- This is the size of the main table heap only
    pg_size_pretty(pg_indexes_size(c.oid)) AS index_size,
    COALESCE(pg_size_pretty(pg_total_relation_size(c_toast.oid)), '0 bytes') AS toast_size, -- Calculate toast table size
    pg_size_pretty(pg_total_relation_size(c.oid)) AS combined_size
FROM
    pg_class c
LEFT JOIN
    pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN
    pg_class c_toast ON c.reltoastrelid = c_toast.oid -- Join to get the TOAST table
WHERE
    c.relkind = 'r' -- 'r' for regular tables
    AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast') -- Exclude system schemas and the pg_toast schema itself
ORDER BY
    pg_total_relation_size(c.oid) DESC
LIMIT 10;



--  schema_name |          table_name          | main_table_size | index_size | toast_size | combined_size 
-- -------------+------------------------------+-----------------+------------+------------+---------------
--  pegadata    | lr_history_data              | 142 GB          | 45 GB      | 660 GB     | 847 GB
--  pegadata    | lr_data_document             | 8691 MB         | 1683 MB    | 666 GB     | 676 GB
--  pegadata    | pc_data_workattach           | 1232 MB         | 173 MB     | 513 GB     | 514 GB
--  pegadata    | pr_ros_data_log_rest         | 1137 MB         | 187 MB     | 60 GB      | 61 GB
--  pegadata    | lr_work                      | 2332 MB         | 1386 MB    | 48 GB      | 51 GB
--  pegadata    | lr_history_work              | 33 GB           | 16 GB      | 8192 bytes | 50 GB
--  pegadata    | pc_history_ros_fw_regfw_work | 9916 MB         | 4752 MB    | 8192 bytes | 14 GB
--  pegadata    | pr_history                   | 7523 MB         | 3018 MB    | 912 kB     | 10 GB
--  pegadata    | pr_ros_data_search_app       | 610 MB          | 143 MB     | 8157 MB    | 8911 MB
--  pegadata    | lr_data_applicationform      | 826 MB          | 432 MB     | 6960 MB    | 8219 MB