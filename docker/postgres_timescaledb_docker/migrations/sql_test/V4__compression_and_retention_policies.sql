
-- COLUMNSTORE / COMPRESSION SETTINGS
ALTER TABLE metrics.cpu SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'host',
  timescaledb.compress_orderby   = 'time DESC'
);

-- COMPRESS CHUNKS OLDER THAN 7 DAYS
SELECT add_compression_policy('metrics.cpu', INTERVAL '7 days', if_not_exists => TRUE);

-- DROP CHUNKS OLDER THAN 90 DAYS
SELECT add_retention_policy('metrics.cpu', INTERVAL '90 days', if_not_exists => TRUE);
