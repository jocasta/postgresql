# Monitoring and troubleshooting

## Key views

| View | Side | Shows |
|---|---|---|
| `pg_stat_replication` | Publisher | One row per walsender: client, state, sent/write/flush/replay LSNs, time lags |
| `pg_replication_slots` | Publisher | Every slot: active, `restart_lsn`, `confirmed_flush_lsn`, `wal_status`, `catalog_xmin` |
| `pg_stat_replication_slots` | Publisher | Decoding stats per logical slot: spill, stream, total txns/bytes (PG 14+) |
| `pg_publication_tables` | Publisher | Tables in each publication (with row filters / column lists from PG 15) |
| `pg_stat_subscription` | Subscriber | One row per apply/sync worker: received LSN, last message times (`worker_type` from PG 17) |
| `pg_stat_subscription_stats` | Subscriber | Error counts per subscription (PG 15+), conflict counts (PG 18+) |
| `pg_subscription` / `pg_subscription_rel` | Subscriber | Subscription config; per-table sync state |
| `pg_replication_origin_status` | Subscriber | Applied position per origin |

```sql
-- publisher: walsenders
SELECT application_name, client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn,
       write_lag, flush_lag, replay_lag, sync_state
FROM pg_stat_replication;
```

```sql
-- subscriber: workers (worker_type is PG 17+; drop it on older versions)
SELECT subname, worker_type, pid, relid::regclass, received_lsn, latest_end_lsn,
       last_msg_send_time, last_msg_receipt_time, latest_end_time
FROM pg_stat_subscription;
```

## Measuring replication lag (bytes and time)

**In bytes (publisher)**: how far the subscriber's confirmed position is behind current WAL:

```sql
SELECT slot_name,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS lag
FROM pg_replication_slots
WHERE slot_type = 'logical';
```

**In time (publisher)**: `pg_stat_replication.replay_lag` / `flush_lag` estimate how long ago the subscriber confirmed WAL that is now current. They go `NULL` when idle; idle doesn't mean lagging.

**In time (subscriber)**: how stale the last applied change is:

```sql
SELECT subname, now() - latest_end_time AS since_last_confirmed,
       now() - last_msg_receipt_time AS since_last_message
FROM pg_stat_subscription
WHERE relid IS NULL;   -- main apply worker only
```

**End-to-end heartbeat** (most reliable): a tiny table updated on the publisher every few seconds and replicated:

```sql
-- publisher
CREATE TABLE IF NOT EXISTS public.repl_heartbeat (id int PRIMARY KEY, ts timestamptz NOT NULL);
INSERT INTO public.repl_heartbeat VALUES (1, now())
ON CONFLICT (id) DO UPDATE SET ts = excluded.ts;     -- run every 10s (pg_cron)

-- subscriber
SELECT now() - ts AS replication_delay FROM public.repl_heartbeat WHERE id = 1;
```

The heartbeat also keeps slots advancing on otherwise idle databases.

## Detecting slot bloat and WAL accumulation

```sql
-- publisher: retained WAL and catalog_xmin age per slot
SELECT slot_name, active, wal_status,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal,
       pg_size_pretty(safe_wal_size)                                       AS safe_wal_size,
       age(catalog_xmin)                                                   AS catalog_xmin_age
FROM pg_replication_slots
ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC NULLS LAST;
```

```sql
-- total size of pg_wal on disk (superuser or pg_monitor)
SELECT pg_size_pretty(sum(size)) AS pg_wal_size, count(*) AS segments FROM pg_ls_waldir();
```

Suggested alerts:

| Metric | Warning | Critical |
|---|---|---|
| Retained WAL per slot | > 10% of free disk | > 30% of free disk |
| Slot inactive | > 15 min | > 1 h |
| `wal_status` | `extended` | `unreserved` / `lost` |
| Subscription disabled (`subenabled = false`) | any | n/a |
| `apply_error_count` increasing | any | n/a |
| Heartbeat delay | > 1 min | > 15 min |
| `age(catalog_xmin)` | > 100M | > 500M |

## Common errors and fixes

| Error (log) | Side | Cause / fix |
|---|---|---|
| `logical decoding requires wal_level >= logical` | Publisher | Set `wal_level = logical`, restart |
| `cannot update table "x" because it does not have a replica identity and publishes updates` | Publisher | Add a PK or set `REPLICA IDENTITY`. See [Replica identity](replica-identity.md) |
| `all replication slots are in use` | Publisher | Raise `max_replication_slots` (restart); drop unused slots |
| `number of requested standby connections exceeds max_wal_senders` | Publisher | Raise `max_wal_senders` |
| `out of logical replication worker slots` | Subscriber | Raise `max_logical_replication_workers` / `max_worker_processes` |
| `logical replication target relation "s.t" does not exist` | Subscriber | Create the table, then `REFRESH PUBLICATION` |
| `... is missing replicated column: "c"` | Subscriber | Add the column on the subscriber |
| `duplicate key value violates unique constraint` | Subscriber | Data diverged. See [Conflicts](conflicts-and-error-handling.md) |
| `replication slot "x" does not exist` | Subscriber log | Slot dropped on publisher; recreate subscription or slot |
| `replication slot "x" is active for PID n` | Subscriber log | Another consumer (or old walsender) holds it; terminate the stale walsender |
| `can no longer get changes from replication slot "x"` / `This slot has been invalidated because it exceeded the maximum reserved size` | Subscriber log | Slot invalidated; full resync required |
| `terminating walsender process due to replication timeout` | Publisher | Raise `wal_sender_timeout` / `wal_receiver_timeout`; enable `streaming` |
| `could not connect to the publisher: ... no pg_hba.conf entry` | Subscriber | Add `pg_hba.conf` entry for the **database name** (not `replication`) |
| `permission denied for table x` (during sync) | Subscriber log | Replication role needs `SELECT` on published tables |

## Useful diagnostic queries

Diagnostic queries for logical replication are kept as collapsible blocks on the [Logical Replication SQL](../sql/logical-replication-queries.md) page, including:

- Subscription table sync state and tables not yet ready
- Tables being synced and publication contents
- Publisher slot LSN distance
- Long-running transactions holding back slots
- Apply worker lock waits and walsender backends
- Replica identity inventory and fix statements
