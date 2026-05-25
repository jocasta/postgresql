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



