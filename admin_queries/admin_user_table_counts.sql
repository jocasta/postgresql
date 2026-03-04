--
-- This runs count(*)  so only run if appropriate
--

SELECT
    schemaname AS schema_name,
    relname    AS table_name,
    (
        xpath(
            '/row/c/text()',
            query_to_xml(
                format('SELECT count(*) AS c FROM %I.%I', schemaname, relname),
                false,
                true,
                ''
            )
        )
    )[1]::text::bigint AS row_count
FROM pg_stat_user_tables
ORDER BY schema_name, table_name;



--        schema_name        |        table_name         | row_count 
-- --------------------------+---------------------------+-----------
--  flyway                   | flyway_schema_history     |        10
--  ros_sid                  | client                    |        14
--  ros_sid                  | client_scope              |        70
--  ros_sid                  | flyway_schema_history     |         1
--  ros_sid                  | instance                  |        26
--  ros_sid                  | instance_grant            |        29
--  ros_sid                  | instance_permission_grant |        19
--  ros_sid                  | permission                |        34