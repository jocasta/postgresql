
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

