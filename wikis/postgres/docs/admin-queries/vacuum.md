# Vacuum

??? example "Postgres Vacuum Activity Estimate Stats"

    ``` sql title="postgres_vacuum_activity_estimate_stats.sql"
    /* Vaccum Stats Script */

    WITH tbl_reloptions AS (
    SELECT
    	oid,
        oid::regclass table_name,
        substr(unnest(reloptions), 1,  strpos(unnest(reloptions), '=') -1) option,
        substr(unnest(reloptions), 1 + strpos(unnest(reloptions), '=')) value
    FROM
        pg_class c
    WHERE reloptions is NOT null)
    SELECT
        now(),
        s.schemaname ||'.'|| s.relname as relname,
        case
          when avacenabled.value is not null
            then avacenabled.value::text
          when (select setting::text from pg_settings where name = 'autovacuum') = 'on'
            then 'true'
          else 'false'
        end as autovac_enabled,
        n_live_tup live_tup,
        n_dead_tup dead_dup,
        n_tup_hot_upd hot_upd,
        n_mod_since_analyze mod_since_stats,
        n_ins_since_vacuum ins_since_vac,
        case 
    	  when avacinsscalefactor.value is not null and avacinsthresh.value is not null
            then ROUND(((n_live_tup * avacinsscalefactor.value::numeric) + avacinsthresh.value::numeric),0)
          when avacinsscalefactor.value is null and avacinsthresh.value is not null
          	then ROUND(((n_live_tup * (select setting::numeric from pg_settings where name = 'autovacuum_vacuum_insert_scale_factor')) + avacinsthresh.value::numeric),0)
          when avacinsscalefactor.value is not null and avacinsthresh.value is null
          	then ROUND(((n_live_tup * avacinsscalefactor.value::numeric) + (select setting::numeric from pg_settings where name = 'autovacuum_vacuum_insert_threshold')),0)
          else ROUND(((n_live_tup * (select setting::numeric from pg_settings where name = 'autovacuum_vacuum_insert_scale_factor')) + (select setting::numeric from pg_settings where name = 'autovacuum_vacuum_insert_threshold')),0) 
        end as ins_for_vac,
        case 
    	  when avacscalefactor.value is not null and avacthresh.value is not null
            then ROUND(((n_live_tup * avacscalefactor.value::numeric) + avacthresh.value::numeric),0)
          when avacscalefactor.value is null and avacthresh.value is not null
          	then ROUND(((n_live_tup * (select setting::numeric from pg_settings where name = 'autovacuum_vacuum_scale_factor')) + avacthresh.value::numeric),0)
          when avacscalefactor.value is not null and avacthresh.value is null
          	then ROUND(((n_live_tup * avacscalefactor.value::numeric) + (select setting::numeric from pg_settings where name = 'autovacuum_vacuum_threshold')),0)
          else ROUND(((n_live_tup * (select setting::numeric from pg_settings where name = 'autovacuum_vacuum_scale_factor')) + (select setting::numeric from pg_settings where name = 'autovacuum_vacuum_threshold')),0) 
        end as mods_for_vac,
        case 
    	  when avacanalyzescalefactor.value is not null and avacanalyzethresh.value is not null
            then ROUND(((n_live_tup * avacanalyzescalefactor.value::numeric) + avacanalyzethresh.value::numeric),0)
          when avacanalyzescalefactor.value is null and avacanalyzethresh.value is not null
          	then ROUND(((n_live_tup * (select setting::numeric from pg_settings where name = 'autovacuum_analyze_scale_factor')) + avacanalyzethresh.value::numeric),0)
          when avacanalyzescalefactor.value is not null and avacanalyzethresh.value is null
          	then ROUND(((n_live_tup * avacanalyzescalefactor.value::numeric) + (select setting::numeric from pg_settings where name = 'autovacuum_analyze_threshold')),0)
          else ROUND(((n_live_tup * (select setting::numeric from pg_settings where name = 'autovacuum_analyze_scale_factor')) + (select setting::numeric from pg_settings where name = 'autovacuum_analyze_threshold')),0) 
        end as mods_for_stats,
        case 
          when avacfreezeage is not null
            then ROUND((greatest(age(c.relfrozenxid),age(t.relfrozenxid))::numeric / avacfreezeage.value::numeric * 100),2) 
          else ROUND((greatest(age(c.relfrozenxid),age(t.relfrozenxid))::numeric / (select setting::numeric from pg_settings where name = 'autovacuum_freeze_max_age') * 100),2) 
          end as avac_pct_frz,
        greatest(age(c.relfrozenxid),age(t.relfrozenxid)) max_txid_age,
        to_char(last_vacuum, 'YYYY-MM-DD HH24:MI:SS') last_vac,
        to_char(last_analyze, 'YYYY-MM-DD HH24:MI:SS') last_stats,
        to_char(last_autovacuum, 'YYYY-MM-DD HH24:MI:SS') last_avac,
        to_char(last_autoanalyze, 'YYYY-MM-DD HH24:MI:SS') last_astats,
        vacuum_count vac_cnt,
        analyze_count stats_cnt,
        autovacuum_count avac_cnt,
        autoanalyze_count astats_cnt,
        c.reloptions
    FROM
        pg_stat_all_tables s
    JOIN pg_class c ON (s.relid = c.oid)
    LEFT JOIN pg_class t ON c.reltoastrelid = t.oid
    LEFT JOIN tbl_reloptions avacinsscalefactor on (s.relid = avacinsscalefactor.oid and avacinsscalefactor.option = 'autovacuum_vacuum_insert_scale_factor')
    LEFT JOIN tbl_reloptions avacinsthresh on (s.relid = avacinsthresh.oid and avacinsthresh.option = 'autovacuum_vacuum_insert_threshold')
    LEFT JOIN tbl_reloptions avacscalefactor on (s.relid = avacscalefactor.oid and avacscalefactor.option = 'autovacuum_vacuum_scale_factor')
    LEFT JOIN tbl_reloptions avacthresh on (s.relid = avacthresh.oid and avacthresh.option = 'autovacuum_vacuum_threshold')
    LEFT JOIN tbl_reloptions avacanalyzescalefactor on (s.relid = avacanalyzescalefactor.oid and avacanalyzescalefactor.option = 'autovacuum_analyze_scale_factor')
    LEFT JOIN tbl_reloptions avacanalyzethresh on (s.relid = avacanalyzethresh.oid and avacanalyzethresh.option = 'autovacuum_analyze_threshold')
    LEFT JOIN tbl_reloptions avacfreezeage on (s.relid = avacfreezeage.oid and avacfreezeage.option = 'autovacuum_freeze_max_age')
    LEFT JOIN tbl_reloptions avacenabled on (s.relid = avacenabled.oid and avacenabled.option = 'autovacuum_enabled')
    WHERE
        s.relname IN (
            SELECT
                t.table_name
            FROM
                information_schema.tables t
                JOIN pg_catalog.pg_class c ON (t.table_name = c.relname)
                JOIN pg_catalog.pg_user u ON (c.relowner = u.usesysid)
            WHERE
                t.table_schema like '%'
                AND u.usename like '%'
                AND t.table_name like '%'
                AND t.table_schema not in ('information_schema','pg_catalog'))
        --AND n_dead_tup > 0
    ORDER BY
        n_dead_tup;
    ```

??? example "Postgres Vacuum Progress Basic"

    ``` sql title="postgres_vacuum_progress_basic.sql"
    /* Basic Vacuum Progress */
    SELECT
        pid,
        datname,
        relid::regclass relname,
        phase,
        heap_blks_total,
        heap_blks_scanned,
        heap_blks_vacuumed,
        round(100.0 * heap_blks_scanned / NULLIF(heap_blks_total, 0), 2) AS pct_scanned,
        round(100.0 * heap_blks_vacuumed / NULLIF(heap_blks_total, 0), 2) AS pct_vacuumed,
        index_vacuum_count,
        max_dead_tuples,
        num_dead_tuples
    FROM
        pg_stat_progress_vacuum;
    ```

??? example "Postgres Vacuum Progress Detailed"

    ``` sql title="postgres_vacuum_progress_detailed.sql"
    /* Detailed Vacuum Progress */
    SELECT
        p.pid,
        now() - a.xact_start AS duration,
        coalesce(wait_event_type || '.' || wait_event, 'f') AS waiting,
        CASE WHEN a.query ~* '^autovacuum.*to prevent wraparound' THEN
            'wraparound'
        WHEN a.query ~* '^vacuum' THEN
            'user'
        ELSE
            'regular'
        END AS mode,
        p.datname AS database,
        p.relid::regclass AS table,
        p.phase,
        pg_size_pretty(p.heap_blks_total * current_setting('block_size')::int) AS table_size,
        pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
        pg_size_pretty(p.heap_blks_scanned * current_setting('block_size')::int) AS scanned,
        pg_size_pretty(p.heap_blks_vacuumed * current_setting('block_size')::int) AS vacuumed,
        round(100.0 * p.heap_blks_scanned / p.heap_blks_total, 1) AS scanned_pct,
        round(100.0 * p.heap_blks_vacuumed / p.heap_blks_total, 1) AS vacuumed_pct,
        p.index_vacuum_count,
        round(100.0 * p.num_dead_tuples / p.max_dead_tuples, 1) AS dead_pct
    FROM
        pg_stat_progress_vacuum p
        JOIN pg_stat_activity a USING (pid)
    ORDER BY
        now() - a.xact_start DESC;
    ```
