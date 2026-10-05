# Locks

??? example "Postgres Blocking Lock PID Tree"

    ``` sql title="postgres_blocking_lock_pid_tree.sql"
    WITH RECURSIVE activity AS (
        SELECT
            pg_blocking_pids (pid) blocked_by,
            *,
            age(clock_timestamp(), xact_start)::interval(0) AS tx_age,
            -- "pg_locks.waitstart" – PG14+ only; for older versions:  age(clock_timestamp(), state_change) as wait_age
            age(clock_timestamp(), (
                SELECT
                    max(l.waitstart)
                FROM pg_locks l
                WHERE
                    a.pid = l.pid))::interval(0) AS wait_age
        FROM
            pg_stat_activity a
        WHERE
            state IS DISTINCT FROM 'idle'
    ),
    blockers AS (
        SELECT
            array_agg(DISTINCT c ORDER BY c) AS pids
        FROM (
            SELECT
                unnest(blocked_by)
            FROM
                activity) AS dt (c)
    ),
    tree AS (
        SELECT
            activity.*,
            1 AS level,
            activity.pid AS top_blocker_pid,
            ARRAY[activity.pid] AS path,
            ARRAY[activity.pid]::int[] AS all_blockers_above
        FROM
            activity,
            blockers
        WHERE
            ARRAY[pid] <@ blockers.pids
            AND blocked_by = '{}'::int[]
        UNION ALL
        SELECT
            activity.*,
            tree.level + 1 AS level,
            tree.top_blocker_pid,
            path || ARRAY[activity.pid] AS path,
            tree.all_blockers_above || array_agg(activity.pid) OVER () AS all_blockers_above
        FROM
            activity,
            tree
        WHERE
            NOT ARRAY[activity.pid] <@ tree.all_blockers_above
            AND activity.blocked_by <> '{}'::int[]
            AND activity.blocked_by <@ tree.all_blockers_above
    )
    SELECT
        pid,
        blocked_by,
        CASE WHEN wait_event_type <> 'Lock' THEN
            replace(state, 'idle in transaction', 'idletx')
        ELSE
            'waiting'
        END AS state,
        wait_event_type || ':' || wait_event AS wait,
        wait_age,
        tx_age,
        to_char(age(backend_xid), 'FM999,999,999,990') AS xid_age,
        to_char(2147483647 - age(backend_xmin), 'FM999,999,999,990') AS xmin_ttf,
        datname,
        usename,
        (
            SELECT
                count(DISTINCT t1.pid)
            FROM
                tree t1
            WHERE
                ARRAY[tree.pid] <@ t1.path
                AND t1.pid <> tree.pid) AS blkd,
        format('%s %s%s', lpad('[' || pid::text || ']', 9, ' '), repeat('.', level -1) || CASE WHEN level > 1 THEN
                ' '
            END,
        LEFT (query, 1000)) AS query
    FROM
        tree
    ORDER BY
        top_blocker_pid,
        level,
        pid;
    ```

??? example "Postgres Blocking Lock SQL"

    ``` sql title="postgres_blocking_lock_sql.sql"
    SELECT
        blocked_locks.pid AS blocked_pid,
        blocked_activity.usename AS blocked_user,
        blocking_locks.pid AS blocking_pid,
        blocking_activity.usename AS blocking_user,
        blocked_activity.query AS blocked_statement,
        blocked_activity.wait_event AS blocked_wait_event,
        blocking_activity.wait_event AS blocking_wait_event,
        blocking_activity.query AS current_statement_in_blocking_process
    FROM
        pg_catalog.pg_locks blocked_locks
        JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
        JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
            AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
            AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
            AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
            AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
            AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
            AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
            AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
            AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
            AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
            AND blocking_locks.pid != blocked_locks.pid
        JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
    WHERE
        NOT blocked_locks.granted;
    ```

??? example "Postgres Blocking Lock Wait Events"

    ``` sql title="postgres_blocking_lock_wait_events.sql"
    select
    	round(EXTRACT(EPOCH FROM (clock_timestamp() - query_start))::numeric, 5) as query_age ,  
        round(EXTRACT(EPOCH FROM (clock_timestamp() -  xact_start))::numeric, 5) as xact_age,
    	pid, 
    	pg_blocking_pids(PID), 
    	wait_event, 
    	substr(query , 1, 80)
    	query ,
    	* 
    	--,  pg_terminate_backend(PID)
    from pg_stat_activity a,
    		(select  unnest( string_to_array(replace(replace(pg_blocking_pids(PID)::text,'{',''),'}',''), ','))  as bpids, 
    		         lower(query)   
    		 from pg_stat_activity
    		 --where lower(query) like '%drop%' or lower(query) like  '%alter%' 
    		) b
    where 
      PID = b.bpids::integer ;
    ```
