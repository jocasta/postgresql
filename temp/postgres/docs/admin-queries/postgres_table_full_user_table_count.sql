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