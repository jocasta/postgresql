# Configuration reference

Defaults are for recent PostgreSQL versions; check `SHOW <name>` on your version.

```sql
SELECT name, setting, unit, context, pending_restart
FROM pg_settings
WHERE name IN ('wal_level', 'max_replication_slots', 'max_wal_senders', 'max_slot_wal_keep_size',
               'logical_decoding_work_mem', 'wal_sender_timeout', 'wal_receiver_timeout',
               'max_logical_replication_workers', 'max_sync_workers_per_subscription',
               'max_parallel_apply_workers_per_subscription', 'max_worker_processes',
               'max_active_replication_origins', 'idle_replication_slot_timeout',
               'track_commit_timestamp')
ORDER BY name;
```

## Publisher parameters

| Parameter | Default | Restart? | Set to |
|---|---|---|---|
| `wal_level` | `replica` | Yes | `logical` |
| `max_replication_slots` | `10` | Yes | One per subscription **plus** one per concurrent tablesync worker, plus physical/CDC slots, plus headroom |
| `max_wal_senders` | `10` | Yes | ≥ `max_replication_slots` used concurrently; include physical standbys and `pg_basebackup` |
| `max_slot_wal_keep_size` | `-1` (unlimited) | No (reload) | A cap below free disk space, e.g. `100GB`. See [Replication slots](replication-slots.md#max_slot_wal_keep_size-and-slot-invalidation) |
| `idle_replication_slot_timeout` | `0` (off) | No | PG 18+: invalidate slots inactive this long |
| `synchronized_standby_slots` | `''` | No | PG 17+: physical slots of failover standbys |
| `logical_decoding_work_mem` | `64MB` | No | Memory per walsender for decoding before spill/stream |

Sizing example: 3 subscriptions, each with `max_sync_workers_per_subscription = 2`, plus 2 physical standbys:

```text
max_replication_slots = 3 (apply) + 3*2 (tablesync) + 2 (physical) + headroom ≈ 16
max_wal_senders       = same order: 16
```

```sql
ALTER SYSTEM SET wal_level = 'logical';
ALTER SYSTEM SET max_replication_slots = 16;
ALTER SYSTEM SET max_wal_senders = 16;
ALTER SYSTEM SET max_slot_wal_keep_size = '100GB';
-- restart required for the first three
```

## Subscriber parameters

| Parameter | Default | Restart? | Notes |
|---|---|---|---|
| `max_logical_replication_workers` | `4` | Yes | Pool for **all** apply, tablesync and parallel apply workers. Needs ≥ subscriptions + sync workers + parallel workers |
| `max_sync_workers_per_subscription` | `2` | No | Tables copied in parallel during initial sync. Raise (e.g. 4–8) for many-table initial loads |
| `max_parallel_apply_workers_per_subscription` | `2` | No | PG 16+: workers for `streaming = parallel` |
| `max_worker_processes` | `8` | Yes | Must be ≥ `max_logical_replication_workers` + 1 (launcher) + parallel query workers + other bgworkers |
| `max_replication_slots` | `10` | Yes | **Before PG 18** this also limits replication **origins** on the subscriber: need ≥ number of subscriptions + headroom |
| `max_active_replication_origins` | `10` | Yes | PG 18+: replaces the above use of `max_replication_slots` on subscribers |
| `track_commit_timestamp` | `off` | Yes | PG 18+: needed for `*_origin_differs` conflict detection |

Example for 3 subscriptions, fast initial load:

```text
max_logical_replication_workers            = 3 (apply) + 3*4 (sync) + 3*2 (parallel) = 21 → 24
max_sync_workers_per_subscription          = 4
max_parallel_apply_workers_per_subscription = 2
max_worker_processes                       = 24 + 1 + max_parallel_workers + others → 40
```

!!! tip
    If tables seem stuck in state `i` (initialize), check the subscriber log for `out of logical replication worker slots` and raise `max_logical_replication_workers`.

## Timeouts and keepalives

| Parameter | Side | Default | Meaning |
|---|---|---|---|
| `wal_sender_timeout` | Publisher | `60s` | Walsender ends the connection if no feedback from the subscriber in this time |
| `wal_receiver_timeout` | Subscriber | `60s` | Apply worker ends the connection if nothing received from the publisher in this time |
| `wal_receiver_status_interval` | Subscriber | `10s` | How often feedback (flush position) is sent |
| `wal_retrieve_retry_interval` | Subscriber | `5s` | Wait before restarting a failed apply/sync worker |

Symptoms of timeouts too low for the workload:

```text
LOG:  terminating walsender process due to replication timeout
```

Typical causes: very large transactions being decoded (walsender busy, not sending keepalives in old versions), a slow network, or a subscriber blocked on locks. Raising both to `5min` is common on busy migration setups. Set per subscription via the connection string too:

```sql
ALTER SUBSCRIPTION sub_app CONNECTION 'host=... dbname=app user=repl keepalives_idle=30 keepalives_interval=10';
```

## Memory and spill settings

| Parameter | Side | Default | Notes |
|---|---|---|---|
| `logical_decoding_work_mem` | Publisher | `64MB` | Per walsender. When exceeded, the largest transaction is spilled to disk (`pg_replslot/<slot>/`) or streamed if `streaming` is on. Raising to 256MB–1GB reduces spill for bulk workloads; mind total memory = value × walsenders |
| `streaming` (subscription option) | Subscriber | `off` / `parallel` (PG 18) | Stream large transactions instead of spilling |
| `maintenance_work_mem` | Subscriber | `64MB` | Used when building indexes after the initial load |
| `work_mem` | Subscriber | `4MB` | Rarely relevant to apply |
| `debug_logical_replication_streaming` | Publisher | `buffered` | PG 16+ developer option (`immediate` forces streaming for testing). Leave at default in production |

Check spilling on the publisher:

```sql
SELECT slot_name, spill_txns, spill_count, pg_size_pretty(spill_bytes) AS spilled,
       stream_txns, pg_size_pretty(stream_bytes) AS streamed, total_txns
FROM pg_stat_replication_slots;
```

High `spill_bytes` → raise `logical_decoding_work_mem` and/or enable `streaming` on the subscription.
