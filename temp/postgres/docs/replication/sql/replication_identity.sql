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
