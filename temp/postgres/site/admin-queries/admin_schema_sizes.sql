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
