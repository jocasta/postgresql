
-- WITH NO DATA allows this to run inside flyway's transaction.
-- (A cagg created WITH DATA, or CALL refresh_continuous_aggregate(), can't run
--  in a transaction - put those in a migration with a matching
--  V<n>__<name>.sql.conf containing: executeInTransaction=false)
CREATE MATERIALIZED VIEW IF NOT EXISTS metrics.cpu_hourly
WITH (timescaledb.continuous) AS
SELECT
  time_bucket(INTERVAL '1 hour', time) AS bucket,
  host,
  avg(usage_user) AS avg_usage_user,
  max(usage_user) AS max_usage_user,
  avg(usage_sys)  AS avg_usage_sys,
  max(usage_sys)  AS max_usage_sys
FROM metrics.cpu
GROUP BY bucket, host
WITH NO DATA;

GRANT SELECT ON metrics.cpu_hourly TO mike;

-- REFRESH EVERY 30 MINS, WINDOW: 3 DAYS AGO -> 1 HOUR AGO
SELECT add_continuous_aggregate_policy(
  'metrics.cpu_hourly',
  start_offset      => INTERVAL '3 days',
  end_offset        => INTERVAL '1 hour',
  schedule_interval => INTERVAL '30 minutes',
  if_not_exists     => TRUE
);
