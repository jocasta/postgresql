
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