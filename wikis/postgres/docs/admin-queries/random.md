# Random

??? example "Database Access Permission Grants"

    ``` sql title="database_access_permission_grants.sql"
    WITH acl AS (
      SELECT
        d.datname,
        unnest(d.datacl::text[]) AS aclitem_txt
      FROM pg_database d
      --WHERE d.datname = 'data_warehouse'
        where d.datacl IS NOT NULL
    ),
    parsed AS (
      SELECT
        datname,
        CASE
          WHEN split_part(aclitem_txt, '=', 1) = '' THEN 'PUBLIC'
          ELSE quote_ident(split_part(aclitem_txt, '=', 1))
        END AS grantee,
        split_part(split_part(aclitem_txt, '=', 2), '/', 1) AS privletters
      FROM acl
    ),
    letters AS (
      SELECT
        datname,
        grantee,
        unnest(string_to_array(regexp_replace(privletters, '\*', '', 'g'), '')) AS letter
      FROM parsed
    )
    SELECT DISTINCT
      format(
        'GRANT %s ON DATABASE %I TO %s;',
        CASE letter
          WHEN 'c' THEN 'CONNECT'
          WHEN 'T' THEN 'TEMPORARY'
          WHEN 'C' THEN 'CREATE'
        END,
        datname,
        grantee
      ) AS grant_sql
    FROM letters
    WHERE letter IN ('c','T','C') ;
    ```

??? example "Postgres Active Parallel Workers"

    ``` sql title="postgres_active_parallel_workers.sql"
    SELECT
        current_setting('max_parallel_workers')::integer AS max_workers,
        count(*) AS active_workers
    FROM
        pg_stat_activity
    WHERE
        backend_type = 'parallel worker';
    ```

??? example "Postgres List Pg Buffercache Blocks For Object"

    ``` sql title="postgres_list_pg_buffercache_blocks_for_object.sql"
    \prompt 'Enter relation name: ' vrelname

    SELECT
        n.nspname,
        c.relname,
        c.relfilenode,
        c.oid,
        b.relblocknumber
    FROM
        pg_buffercache b
        JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
            AND b.reldatabase IN (0, (
                    SELECT
                        oid
                    FROM pg_database
                WHERE
                    datname = current_database()))
            JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = :'vrelname'
        ORDER BY
            5;
    ```

??? example "Postgres List Pg Buffercache For All Objects"

    ``` sql title="postgres_list_pg_buffercache_for_all_objects.sql"
    SELECT
        n.nspname,
        c.relname,
        count(*) AS buffers
    FROM
        pg_buffercache b
        JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
            AND b.reldatabase IN (0, (
                    SELECT
                        oid
                    FROM pg_database
                WHERE
                    datname = current_database()))
            JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE
            n.nspname = 'public'
        GROUP BY
            n.nspname,
            c.relname
        ORDER BY
            3 DESC;
    ```

??? example "Postgres Monitor Waits"

    ``` sql title="postgres_monitor_waits.sql"
    \prompt 'Enter PID to check: ' pidvar
    select 
      pid, 
      usename, 
      application_name, 
      TO_CHAR(
        backend_start, 'YYYY-MM-DD HH24:MI') as backend_start, 
      TO_CHAR(
        xact_start, 'YYYY-MM-DD HH24:MI:SS') as xact_start, 
      TO_CHAR(
        query_start, 'YYYY-MM-DD HH24:MI:SS') as query_start, 
      TO_CHAR(
        state_change, 'YYYY-MM-DD HH24:MI') as state_change, 
      wait_event_type, 
      wait_event, 
      state, 
      query_id, 
      query 
    from 
      pg_stat_activity 
    where 
      pid = :'pidvar';

    \watch 1
    ```

??? example "Postgres Non Default Params"

    ``` sql title="postgres_non_default_params.sql"
    SELECT name, source, setting 
    	FROM pg_settings  
    	WHERE source != 'default' 
    	AND source != 'override' 
    	ORDER by 2, 1;
    ```

??? example "Postgres Queries Running In Parallel"

    ``` sql title="postgres_queries_running_in_parallel.sql"
    SELECT query, leader_pid,
      array_agg(pid) filter(WHERE leader_pid != pid) AS members
    FROM pg_stat_activity
    WHERE leader_pid IS NOT NULL
    GROUP BY query, leader_pid;
    ```

??? example "Postgres Top 10 Long Running Queries"

    ``` sql title="postgres_top_10_long_running_queries.sql"
    SELECT pid, age(backend_xid) AS age_in_xids, 
        now () - xact_start AS xact_age, 
        now () - query_start AS query_age, 
        state, 
        query 
        FROM pg_stat_activity 
        WHERE state != 'idle' 
        ORDER BY 2 DESC 
        LIMIT 10;
    ```

??? example "Postgres Top 10 Objects Using Pg Buffercache"

    ``` sql title="postgres_top_10_objects_using_pg_buffercache.sql"
    SELECT
        n.nspname,
        c.relname,
        c.relfilenode,
        c.oid,
        min(b.relblocknumber),
        max(b.relblocknumber),
        count(*) AS buffers
    FROM
        pg_buffercache b
        JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
            AND b.reldatabase IN (0, (
                    SELECT
                        oid
                    FROM pg_database
                WHERE
                    datname = current_database()))
            JOIN pg_namespace n ON n.oid = c.relnamespace
        GROUP BY
            n.nspname,
            c.relname,
            c.relfilenode,
            c.oid
        ORDER BY
            7 DESC
        LIMIT 10;
    ```

??? example "Postgres Top 10 SQL By Execution"

    ``` sql title="postgres_top_10_sql_by_execution.sql"
    WITH
    hist AS (
    SELECT queryid::text,
           SUBSTRING(query from 1 for 100) query,
           ROW_NUMBER () OVER (ORDER BY calls DESC) rn,
           calls
      FROM pg_stat_statements 
     WHERE queryid IS NOT NULL 
     		AND query::text not like '%pg_%' 
     		AND query::text not like '%g_%'
     		AND query::text not like '%heartbeat%'
      		AND query::text not like '%SELECT $1%'
      		AND query::text not like '%google_%'
      		AND query::text not like 'SELECT txid_current%'
      		AND query::text not like 'CREATE TEMPORARY TABLE%'
      		AND query::text not like 'EXPLAIN%'
      		AND query::text not like 'vacuum%'
      		AND query::text not like 'analyze%'
     GROUP BY
           queryid,
           SUBSTRING(query from 1 for 100),
           calls
    ),
    total AS (
    SELECT SUM(calls) calls FROM hist
    )
    SELECT DISTINCT
           h.queryid::text,
           h.calls,
           ROUND(100 * h.calls / t.calls, 1) percent,
           h.query
      FROM hist h,
           total t
     WHERE h.calls >= t.calls / 1000 AND rn <= 14
     UNION ALL
    SELECT 'Others',
           COALESCE(SUM(h.calls), 0) calls,
           COALESCE(ROUND(100 * SUM(h.calls) / AVG(t.calls), 1), 0) percent,
           NULL sql_text
      FROM hist h,
           total t
     WHERE h.calls < t.calls / 1000 OR rn > 14
     ORDER BY 2 DESC NULLS LAST;
    ```

??? example "Postgres Top 10 SQL By Mean Exec Time"

    ``` sql title="postgres_top_10_sql_by_mean_exec_time.sql"
    /* Top SQL by Mean Exec Time */
    WITH
    hist AS (
    SELECT queryid::text,
           SUBSTRING(query from 1 for 100) query,
           ROW_NUMBER () OVER (ORDER BY mean_exec_time::numeric DESC) rn,
           SUM(mean_exec_time::numeric) mean_exec_time
      FROM pg_stat_statements
     WHERE queryid IS NOT NULL
     		AND query::text not like '%pg_%' 
     		AND query::text not like '%g_%'
     		AND query::text not like '%heartbeat%'
      		AND query::text not like '%SELECT $1%'
      		AND query::text not like '%google_%'
      		AND query::text not like 'SELECT txid_current%'
      		AND query::text not like 'CREATE TEMPORARY TABLE%'
      		AND query::text not like 'EXPLAIN%'
      		AND query::text not like 'DROP EXTENSION%'
      		AND query::text not like 'vacuum%'
      		AND query::text not like 'analyze%'
      		AND query::text not like 'COPY%'
      		AND query::text not like 'FETCH FORWARD%'
      		AND query::text not like '%shared_buffers_active%'
     GROUP BY
           queryid,
           SUBSTRING(query from 1 for 100),
           mean_exec_time::numeric
    ),
    total AS (
    SELECT SUM(mean_exec_time::numeric) mean_exec_time FROM hist
    )
    SELECT DISTINCT
           h.queryid::text,
           ROUND(h.mean_exec_time::numeric,3) mean_exec_time,
           ROUND(100 * h.mean_exec_time / t.mean_exec_time, 1) percent,
           h.query
      FROM hist h,
           total t
     WHERE h.mean_exec_time >= t.mean_exec_time / 1000 AND rn <= 14
     UNION ALL
    SELECT 'Others',
           ROUND(COALESCE(SUM(h.mean_exec_time), 0), 3) mean_exec_time,
           COALESCE(ROUND(100 * SUM(h.mean_exec_time) / AVG(t.mean_exec_time), 1), 0) percent,
           NULL sql_text
      FROM hist h,
           total t
     WHERE h.mean_exec_time < t.mean_exec_time / 1000 OR rn > 14
     ORDER BY 3 DESC NULLS LAST;
    ```

??? example "Postgres Top 10 SQL By Total Exec Time"

    ``` sql title="postgres_top_10_sql_by_total_exec_time.sql"
    /* Top SQL by Total Exec Time */
    WITH
    hist AS (
    SELECT queryid::text,
           SUBSTRING(query from 1 for 100) query,
           ROW_NUMBER () OVER (ORDER BY total_exec_time::numeric DESC) rn,
           SUM(total_exec_time::numeric) total_exec_time
      FROM pg_stat_statements
     WHERE queryid IS NOT NULL
     		AND query::text not like '%pg_%' 
     		AND query::text not like '%g_%'
     		AND query::text not like '%heartbeat%'
      		AND query::text not like '%SELECT $1%'
      		AND query::text not like '%google_%'
      		AND query::text not like 'SELECT txid_current%'
      		AND query::text not like 'CREATE TEMPORARY TABLE%'
      		AND query::text not like 'EXPLAIN%'
      		AND query::text not like 'vacuum%'
      		AND query::text not like 'analyze%'
     GROUP BY
           queryid,
           SUBSTRING(query from 1 for 100),
           total_exec_time::numeric
    ),
    total AS (
    SELECT SUM(total_exec_time::numeric) total_exec_time FROM hist
    )
    SELECT DISTINCT
           h.queryid::text,
           ROUND(h.total_exec_time::numeric,3) total_exec_time,
           ROUND(100 * h.total_exec_time / t.total_exec_time, 1) percent,
           h.query
      FROM hist h,
           total t
     WHERE h.total_exec_time >= t.total_exec_time / 1000 AND rn <= 14
     UNION ALL
    SELECT 'Others',
           ROUND(COALESCE(SUM(h.total_exec_time::numeric), 0), 3) total_exec_time,
           COALESCE(ROUND(100 * SUM(h.total_exec_time) / AVG(t.total_exec_time), 1), 0) percent,
           NULL sql_text
      FROM hist h,
           total t
     WHERE h.total_exec_time < t.total_exec_time / 1000 OR rn > 14
     ORDER BY 3 DESC NULLS LAST;
    ```

??? example "Postgres Top 10 Table Seq Scans"

    ``` sql title="postgres_top_10_table_seq_scans.sql"
    SELECT
        relid,
        relname,
        seq_scan,
        pg_size_pretty(pg_relation_size(relid))
    FROM
        pg_stat_user_tables
    ORDER BY
        seq_scan DESC
    LIMIT 10;
    ```

??? example "Postgres Transaction Age By Table Wraparound Risk"

    ``` sql title="postgres_transaction_age_by_table_wraparound_risk.sql"
    SELECT
        c.oid::regclass AS table_name,
        greatest (age(c.relfrozenxid), age(t.relfrozenxid)) AS "TXID age",
        (greatest (age(c.relfrozenxid), age(t.relfrozenxid))::numeric / 1000000000 * 100)::numeric(4, 2) AS "% WRAPAROUND RISK"
    FROM
        pg_class c
        LEFT JOIN pg_class t ON c.reltoastrelid = t.oid
    WHERE
        c.relkind IN ('r', 'm')
    ORDER BY
        2 DESC;
    ```

??? example "Postgres Waits By Individual PID"

    ``` sql title="postgres_waits_by_individual_pid.sql"
    \prompt 'Enter PID to check: ' pidvar
    SELECT
        pid,
        usename,
        application_name,
        TO_CHAR(backend_start, 'YYYY-MM-DD HH24:MI') AS backend_start,
        TO_CHAR(xact_start, 'YYYY-MM-DD HH24:MI:SS') AS xact_start,
        TO_CHAR(query_start, 'YYYY-MM-DD HH24:MI:SS') AS query_start,
        TO_CHAR(state_change, 'YYYY-MM-DD HH24:MI') AS state_change,
        wait_event_type,
        wait_event,
        state,
        query_id,
        query
    FROM
        pg_stat_activity
    WHERE
        pid = :'pidvar';

    \watch 1
    ```
