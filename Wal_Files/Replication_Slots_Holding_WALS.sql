
-- This will give you the name of the oldest WAL file each replication slot still needs.
SELECT slot_name,
       lpad((pg_control_checkpoint()).timeline_id::text, 8, '0') ||
       lpad(split_part(restart_lsn::text, '/', 1), 8, '0') ||
       lpad(substr(split_part(restart_lsn::text, '/', 2), 1, 2), 8, '0')
       AS wal_file
FROM pg_replication_slots;


-- NEWER VERSION THAT ALSO GRABS THE LAST MODIFIED DATE FROM DISK

WITH slot_wals AS (
  SELECT
    slot_name,
    /* use the helper to turn an LSN into its segment file name */
    pg_walfile_name(restart_lsn) AS wal_file
  FROM pg_replication_slots
)
SELECT
  s.slot_name,
  s.wal_file,
  /* look up that file under pg_wal/ and grab its modification timestamp */
  stat.modification AS last_modified
FROM
  slot_wals s
  /* LATERAL lets us call pg_stat_file() once per row */
  LEFT JOIN LATERAL pg_stat_file('pg_wal/' || s.wal_file) AS stat
    ON TRUE
;


-------------------------------------------------------------------------------------------
--- Include Pending_WAL to Sync -----------------------------------------------------------
-------------------------------------------------------------------------------------------

WITH slot_wals AS (
  SELECT
    slot_name,
    restart_lsn,
    pg_walfile_name(restart_lsn) AS wal_file
  FROM pg_replication_slots
)
SELECT
  s.slot_name,
  s.wal_file,
  -- NULL if the WAL file has already been recycled
  stat.modification AS last_modified,
  -- pretty-printed pending WAL size
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), s.restart_lsn)) AS pending_wal_pretty
FROM
  slot_wals s
  -- missing_ok = true so we don't error if the segment has gone
  LEFT JOIN LATERAL pg_stat_file('pg_wal/' || s.wal_file, true) AS stat
    ON TRUE
ORDER BY
  pg_wal_lsn_diff(pg_current_wal_lsn(), s.restart_lsn) ASC;
