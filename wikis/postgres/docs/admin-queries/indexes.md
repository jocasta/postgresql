# Indexes

??? example "Postgres Duplicate Indexes"

    ``` sql title="postgres_duplicate_indexes.sql"
    SELECT
        c.relname AS relname,
        pg_size_pretty(sum(pg_relation_size(idx))::bigint) AS size,
        (array_agg(idx))[1] AS idx1,
        (array_agg(idx))[2] AS idx2,
        (array_agg(idx))[3] AS idx3,
        (array_agg(idx))[4] AS idx4
    FROM (
        SELECT
            indrelid,
            indexrelid::regclass AS idx,
            (indrelid::text || E'\n' || indclass::text || E'\n' || indkey::text || E'\n' || coalesce(indexprs::text, '') || E'\n' || coalesce(indpred::text, '')) AS key
        FROM
            pg_index) sub
        JOIN pg_class c ON (c.oid = sub.indrelid)
    GROUP BY
        relname,
        key
    HAVING
        count(*) > 1
    ORDER BY
        sum(pg_relation_size(idx)) DESC;
    ```

??? example "Postgres Index Cache Ratio"

    ``` sql title="postgres_index_cache_ratio.sql"
    SELECT 
    	relname,
    	indexrelname, 
    	sum(idx_blks_read) as idx_read, 
    	sum(idx_blks_hit)  as idx_hit, 
    	ROUND((sum(idx_blks_hit) - sum(idx_blks_read)) / sum(idx_blks_hit),4) as ratio
    FROM pg_statio_user_indexes
    WHERE (idx_blks_read > 0 and idx_blks_hit > 0) AND relname like '%' AND indexrelname like '%'
    GROUP BY 
    	relname,
    	indexrelname;
    ```

??? example "Postgres Index Information Details"

    ``` sql title="postgres_index_information_details.sql"
    \prompt 'Enter schema_name: ' vSchemaName
    SELECT
        pg_class.relname,
        pg_size_pretty(pg_class.reltuples::bigint)            AS rows_in_bytes,
        pg_class.reltuples                                    AS num_rows,
        COUNT(*)                                              AS total_indexes,
        COUNT(*) FILTER ( WHERE indisunique)                  AS unique_indexes,
        COUNT(*) FILTER ( WHERE indnatts = 1 )                AS single_column_indexes,
        COUNT(*) FILTER ( WHERE indnatts IS DISTINCT FROM 1 ) AS multi_column_indexes
    FROM
        pg_namespace
        LEFT JOIN pg_class ON pg_namespace.oid = pg_class.relnamespace
        LEFT JOIN pg_index ON pg_class.oid = pg_index.indrelid
    WHERE
        pg_namespace.nspname = :'vSchemaName' AND
        pg_class.relkind = 'r'
    GROUP BY pg_class.relname, pg_class.reltuples
    ORDER BY pg.namespace.nspname, pg_class.reltuples DESC;
    ```

??? example "Postgres Index Information Query"

    ``` sql title="postgres_index_information_query.sql"
    \prompt 'Enter schema_name: ' vSchemaName
    SELECT
        pg_class.relname,
        pg_size_pretty(pg_class.reltuples::bigint)            AS rows_in_bytes,
        pg_class.reltuples                                    AS num_rows,
        COUNT(*)                                              AS total_indexes,
        COUNT(*) FILTER ( WHERE indisunique)                  AS unique_indexes,
        COUNT(*) FILTER ( WHERE indnatts = 1 )                AS single_column_indexes,
        COUNT(*) FILTER ( WHERE indnatts IS DISTINCT FROM 1 ) AS multi_column_indexes
    FROM
        pg_namespace
        LEFT JOIN pg_class ON pg_namespace.oid = pg_class.relnamespace
        LEFT JOIN pg_index ON pg_class.oid = pg_index.indrelid
    WHERE
        pg_namespace.nspname = :'vSchemaName' AND
        pg_class.relkind = 'r'
    GROUP BY pg_class.relname, pg_class.reltuples
    ORDER BY pg.namespace.nspname, pg_class.reltuples DESC;
    ```

??? example "Postgres Index Usage Stats"

    ``` sql title="postgres_index_usage_stats.sql"
    \prompt 'Enter schema_name: ' vSchemaName
    SELECT
        t.schemaname,
        t.tablename,
        c.reltuples::bigint                            AS num_rows,
        pg_size_pretty(pg_relation_size(c.oid))        AS table_size,
        psai.indexrelname                              AS index_name,
        pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size,
        CASE WHEN i.indisunique THEN 'Y' ELSE 'N' END  AS "unique",
        psai.idx_scan                                  AS number_of_scans,
        psai.idx_tup_read                              AS tuples_read,
        psai.idx_tup_fetch                             AS tuples_fetched
    FROM
        pg_tables t
        LEFT JOIN pg_class c ON t.tablename = c.relname
        LEFT JOIN pg_index i ON c.oid = i.indrelid
        LEFT JOIN pg_stat_all_indexes psai ON i.indexrelid = psai.indexrelid
    WHERE
        t.schemaname NOT IN ('pg_catalog', 'information_schema')
        AND t.schemaname IN (:'vSchemaName')
    ORDER BY 1, 2;
    ```

??? example "Postgres Indexes Supporting PK Constraints"

    ``` sql title="postgres_indexes_supporting_pk_constraints.sql"
    \prompt 'Enter schema_name: ' vSchemaName
    SELECT
        n.nspname schema_name,
        c.conname constraint_name,
        c.contype constraint_type,
        i.relname index_name,
        t.relname table_name
    FROM
        pg_constraint c
        JOIN pg_namespace n ON (c.connamespace = n.oid
                AND n.nspname = :'vSchemaName')
        JOIN pg_class i ON (c.conindid = i.oid)
        JOIN pg_class t ON (c.conrelid = t.oid)
    WHERE
        c.contype = 'p';
    ```

??? example "Postgres Unindexed Foreign Keys"

    ``` sql title="postgres_unindexed_foreign_keys.sql"
    WITH y AS (
        SELECT
            pg_catalog.format('%I.%I', n1.nspname, c1.relname) AS referencing_tbl,
            pg_catalog.quote_ident(a1.attname) AS referencing_column,
            t.conname AS existing_fk_on_referencing_tbl,
            pg_catalog.format('%I.%I', n2.nspname, c2.relname) AS referenced_tbl,
            pg_catalog.quote_ident(a2.attname) AS referenced_column,
            pg_relation_size(pg_catalog.format('%I.%I', n1.nspname, c1.relname)) AS referencing_tbl_bytes,
            pg_relation_size(pg_catalog.format('%I.%I', n2.nspname, c2.relname)) AS referenced_tbl_bytes,
            pg_catalog.format($$CREATE INDEX %I_idx ON %I.%I(%I);$$, t.conname, n1.nspname, c1.relname, a1.attname) AS suggestion
        FROM
            pg_catalog.pg_constraint t
            JOIN pg_catalog.pg_attribute a1 ON a1.attrelid = t.conrelid
                AND a1.attnum = t.conkey[1]
            JOIN pg_catalog.pg_class c1 ON c1.oid = t.conrelid
            JOIN pg_catalog.pg_namespace n1 ON n1.oid = c1.relnamespace
            JOIN pg_catalog.pg_class c2 ON c2.oid = t.confrelid
            JOIN pg_catalog.pg_namespace n2 ON n2.oid = c2.relnamespace
            JOIN pg_catalog.pg_attribute a2 ON a2.attrelid = t.confrelid
                AND a2.attnum = t.confkey[1]
        WHERE
            t.contype = 'f'
            AND NOT EXISTS (
                SELECT
                    1
                FROM
                    pg_catalog.pg_index i
                WHERE
                    i.indrelid = t.conrelid
                    AND i.indkey[0] = t.conkey[1]))
    SELECT
        referencing_tbl,
        referencing_column,
        existing_fk_on_referencing_tbl,
        referenced_tbl,
        referenced_column,
        pg_size_pretty(referencing_tbl_bytes) AS referencing_tbl_size,
        pg_size_pretty(referenced_tbl_bytes) AS referenced_tbl_size,
        suggestion
    FROM
        y
    ORDER BY
        referencing_tbl_bytes DESC,
        referenced_tbl_bytes DESC,
        referencing_tbl,
        referenced_tbl,
        referencing_column,
        referenced_column;
    ```
