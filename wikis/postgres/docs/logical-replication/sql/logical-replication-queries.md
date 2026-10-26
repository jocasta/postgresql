# Logical Replication SQL

??? example "Postgres Logical Replication Subscription Tables Sync State"

    ``` sql title="logical_replication_subscription_tables_sync_state.sql"
    -- SHOW SUBSCRIPTION TABLES

    SELECT 
        s.subname AS subscription_name,
        n.nspname AS schema_name,
        c.relname AS table_name,
        sr.srsubstate AS state_code,
        CASE sr.srsubstate
            WHEN 'i' THEN 'initialize'
            WHEN 'd' THEN 'data copy'
            WHEN 's' THEN 'synchronized'
            WHEN 'r' THEN 'ready (normal)'
            ELSE 'unknown'
        END AS sync_status
    FROM pg_subscription_rel sr
    JOIN pg_subscription s ON s.oid = sr.srsubid
    JOIN pg_class c ON c.oid = sr.srrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    ORDER BY sync_status, table_name;


    --          subscription_name         |  schema_name   |           table_name           | state_code |  sync_status   
    -- -----------------------------------+----------------+--------------------------------+------------+----------------
    --  osmm_archiving_datawarehouse_prod | osmm_archiving | a_boundaryline                 | r          | ready (normal)
    --  osmm_archiving_datawarehouse_prod | osmm_archiving | a_cartographicsymbol           | r          | ready (normal)
    --  osmm_archiving_datawarehouse_prod | osmm_archiving | a_cartographictext             | r          | ready (normal)
    --  osmm_archiving_datawarehouse_prod | osmm_archiving | a_topographicarea              | r          | ready (normal)
    --  osmm_archiving_datawarehouse_prod | osmm_archiving | a_topographicline              | r          | ready (normal)
    --  osmm_archiving_datawarehouse_prod | osmm_archiving | a_topographicpoint             | r          | ready (normal)
    --  osmm_archiving_datawarehouse_prod | osmm_archiving | boundaryline                   | r          | ready (normal)
    --  osmm_archiving_datawarehouse_prod | osmm_archiving | cartographicsymbol             | r          | ready (normal)
    --  osmm_archiving_datawarehouse_prod | osmm_archiving | cartographictext               | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | report_event                   | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | report_event_type              | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | ros_report_applicationform     | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | ros_report_applicationtype     | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | ros_report_assign              | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | ros_report_case                | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | ros_report_casecharacteristics | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | ros_report_lrs                 | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | ros_report_property            | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | ros_report_qadatapoint         | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | ros_report_qafailure           | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | ros_report_qafailurereason     | r          | ready (normal)
    --  cmsreports_prd                    | pegareports    | ros_report_rejection           | r          | ready (normal)
    --  osmm_archiving_datawarehouse_prod | osmm_archiving | topographicarea                | r          | ready (normal)
    --  osmm_archiving_datawarehouse_prod | osmm_archiving | topographicline                | r          | ready (normal)
    --  osmm_archiving_datawarehouse_prod | osmm_archiving | topographicpoint               | r          | ready (normal)
    ```

??? example "Postgres Logical Replication Subscriber Tables Being Synced"

    ``` sql title="logical_replication_subscriber_tables_being_synced.sql"
    -- On subscriber show - tables being synced

    select a.*, a.relid::regclass::text AS table_name
    from pg_stat_subscription a, pg_class b
    where a.relid = b.oid ;


    --  -[ RECORD 1 ]---------+------------------------------
    -- subid                 | 10763722
    -- subname               | sub_pega_full_replication
    -- pid                   | 35506
    -- relid                 | 10759330
    -- received_lsn          | 
    -- last_msg_send_time    | 2024-01-18 19:03:17.586797+00
    -- last_msg_receipt_time | 2024-01-18 19:03:17.586797+00
    -- latest_end_lsn        | 
    -- latest_end_time       | 2024-01-18 19:03:17.586797+00
    -- table_name            | pegadata.lr_history_data
    ```

??? example "Postgres Logical Replication Publisher Slot LSN Distance"

    ``` sql title="logical_replication_publisher_slot_lsn_distance.sql"
    -- Publisher Side - Once the "lsn_distance" reaches 0, the new cluster is in sync with the old one.
    SELECT slot_name, confirmed_flush_lsn, pg_current_wal_lsn(), (pg_current_wal_lsn() - confirmed_flush_lsn) AS lsn_distance
    FROM pg_catalog.pg_replication_slots
    WHERE slot_type = 'logical'
    ```

??? example "Postgres Replication Identity"

    ``` sql title="replication_identity.sql"
    -- REPLICATION IDENTITY

    SELECT
      nsp.nspname AS schema_name,
      cls.relname AS table_name,
      cls.relreplident,
      CASE
        WHEN cls.relreplident = 'd' AND idx.indisprimary = 't' THEN 'default (primary key)'
        WHEN cls.relreplident = 'd' THEN 'default'
        WHEN cls.relreplident = 'n' THEN 'nothing'
        WHEN cls.relreplident = 'f' THEN 'full (all columns)'
        WHEN cls.relreplident = 'i' THEN idx_columns.index_columns
      END AS replication_identity,
      idx.indisprimary,
      index_agg.index_columns
    FROM
      pg_class cls
      JOIN pg_namespace nsp ON cls.relnamespace = nsp.oid
      LEFT JOIN pg_index idx ON cls.oid = idx.indrelid AND idx.indisprimary
      LEFT JOIN (
        SELECT
          indrelid,
          string_agg(attname, ', ' ORDER BY attnum) AS index_columns
        FROM
          pg_index
          JOIN pg_attribute ON pg_index.indexrelid = pg_attribute.attrelid AND attnum > 0
        GROUP BY
          indrelid
      ) AS index_agg ON cls.oid = index_agg.indrelid
      LEFT JOIN (
        SELECT
          indrelid,
          string_agg(attname, ', ' ORDER BY attnum) AS index_columns
        FROM
          pg_attribute
          JOIN pg_index ON pg_index.indexrelid = pg_attribute.attrelid
        WHERE
          attnum > 0 AND indisreplident
        GROUP BY
          indrelid
      ) AS idx_columns ON cls.oid = idx_columns.indrelid
    WHERE
      cls.relkind = 'r' AND
      nsp.nspname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY
      schema_name, table_name;



    --  schema_name |         table_name          | relreplident | replication_identity  | indisprimary |                                                      index_columns                                                      
    -- -------------+-----------------------------+--------------+-----------------------+--------------+-------------------------------------------------------------------------------------------------------------------------
    --  _flyway     | schema_version              | d            | default (primary key) | t            | installed_rank, success
    --  cron        | job                         | d            | default (primary key) | t            | jobid, jobname, username
    --  cron        | job_run_details             | d            | default (primary key) | t            | runid
    --  lrm         | county                      | d            | default (primary key) | t            | county_key, county_label, county_id
    --  lrm         | deduplicated_polygon        | d            | default (primary key) | t            | deduplicated_polygon_id, geom, job_id
    --  lrm         | deduplicated_polygon_result | d            | default (primary key) | t            | polygon_result_id, deduplicated_polygon_id, job_id
    --  lrm         | job                         | d            | default (primary key) | t            | is_default, label, job_id
    --  lrm         | polygon_status              | d            | default (primary key) | t            | status_id, status_key, status_label, status_title_priority, status_polygon_priority
    --  lrm         | title                       | d            | default (primary key) | t            | dmst_title_plan_id, title_number, job_id, job_id
    --  lrm         | title_polygon               | d            | default (primary key) | t            | lrsu_polygon_id, deduplicated_polygon_id, job_id, job_id
    --  lrm         | title_polygon_link          | d            | default (primary key) | t            | title_polygon_link_id, lrsu_polygon_id, lrsu_polygon_id, dmst_title_plan_id, job_id, job_id, dmst_title_plan_id, job_id
    --  public      | spatial_ref_sys             | d            | default (primary key) | t            | srid
    --  public      | users                       | d            | default (primary key) | t            | id
    --  public      | users_2                     | d            | default               |              | id
    ```


??? example "Inventory of all tables (schema, rows, size, replica identity)"

    ``` sql title="replication_identity_inventory.sql"
    -- replication_identity_inventory
    SELECT s.schemaname,
           s.relname                                       AS tablename,
           s.n_live_tup                                    AS row_count,
           pg_size_pretty(pg_total_relation_size(s.relid)) AS table_size,
           CASE
             WHEN c.relreplident = 'f' THEN 'full'
             WHEN c.relreplident = 'i' THEN 'index'
             WHEN c.relreplident = 'n' THEN 'nothing'
             WHEN EXISTS (SELECT 1 FROM pg_index i
                          WHERE i.indrelid = s.relid AND i.indisprimary)
                  THEN 'default (primary key)'
             ELSE 'default (NO PK, nothing logged)'
           END                                             AS replica_identity,
           EXISTS (SELECT 1 FROM pg_index i
                   WHERE i.indrelid = s.relid AND i.indisprimary) AS has_primary_key
    FROM pg_stat_user_tables s
    JOIN pg_class c ON c.oid = s.relid
    WHERE s.schemaname IN ('ARTL','CEASYS','IR','REF','lrarchive','lrmigration','lrsubmission')
    ORDER BY pg_total_relation_size(s.relid) DESC;

    -- schemaname |  tablename  | row_count | table_size |   replica_identity    | has_primary_key 
    -- -------------+-------------+-----------+------------+-----------------------+-----------------
    -- IR         | RENDITION   |  23030055 | 61 GB      | default (primary key) | t
    -- CEASYS     | ROS_RECORDS |  14813072 | 11 GB      | default (primary key) | t
    -- CEASYS     | DOCTABLE    |  44717125 | 6460 MB    | default (primary key) | t
    -- IR         | DOCUMENT    |  26650663 | 3652 MB    | default (primary key) | t
    -- IR         | APPLICATION |   4974537 | 1160 MB    | default (primary key) | t
    ```


??? example "Generate the REPLICA IDENTITY FULL statements for the 18 tables with no primary key"

    ``` sql title="replication_identity_generate_statements.sql"
    --replication_identity_generate_statements
    SELECT format('ALTER TABLE %I.%I REPLICA IDENTITY FULL;', n.nspname, c.relname) AS fix_statement
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r'
      AND n.nspname IN ('ARTL','CEASYS','IR','REF','lrarchive','lrmigration','lrsubmission')
      AND c.relreplident = 'd'
      AND NOT EXISTS (SELECT 1 FROM pg_index i
                      WHERE i.indrelid = c.oid AND i.indisprimary)
    ORDER BY n.nspname, c.relname;
    ```
