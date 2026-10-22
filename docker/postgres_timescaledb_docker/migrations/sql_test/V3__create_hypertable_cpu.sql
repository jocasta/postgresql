
-- PLAIN TABLE, THEN CONVERT TO A HYPERTABLE (1 DAY CHUNKS)
CREATE TABLE IF NOT EXISTS metrics.cpu (
  time        TIMESTAMPTZ      NOT NULL,
  host        TEXT             NOT NULL,
  usage_user  DOUBLE PRECISION,
  usage_sys   DOUBLE PRECISION
);

SELECT create_hypertable(
  'metrics.cpu',
  by_range('time', INTERVAL '1 day'),
  if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS cpu_host_time_idx ON metrics.cpu (host, time DESC);
