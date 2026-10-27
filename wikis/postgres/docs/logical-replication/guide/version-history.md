# Version history

Logical decoding (the WAL-to-changes engine with slots and output plugins) arrived in **PostgreSQL 9.4** (2014). Before PG 10, PG → PG logical replication needed extensions such as **pglogical**.

## PostgreSQL 10: initial native logical replication

- `CREATE PUBLICATION` / `CREATE SUBSCRIPTION`.
- `pgoutput` output plugin and logical replication protocol.
- Initial table synchronisation via tablesync workers.
- `INSERT`, `UPDATE`, `DELETE` only.
- `pg_stat_subscription`, `pg_publication_tables`.

**PG 11**: replication of `TRUNCATE`.

**PG 12**: mostly internal improvements.

## PostgreSQL 13: partitioned table support

- Publish **partitioned tables** (all partitions automatically included).
- `publish_via_partition_root` publication option.
- Subscribe **into** partitioned tables (subscriber-side routing).
- `logical_decoding_work_mem` parameter.
- `max_slot_wal_keep_size` and `wal_status` / `safe_wal_size` in `pg_replication_slots`.

## PostgreSQL 14: streaming in-progress transactions, binary mode

- `streaming = on`: stream large transactions before commit.
- `binary = true`: binary data transfer.
- `pg_stat_replication_slots` view (spill/stream statistics).
- Decoding of prepared transactions in the output plugin API (subscription support came in 15).
- Tablesync improvements: permanent sync slots, `f` (finished copy) state.
- `ALTER SUBSCRIPTION ... ADD/DROP PUBLICATION`.

## PostgreSQL 15: row filters, column lists, schema publications, two-phase

- **Row filters** (`WHERE`) and **column lists** on published tables.
- `FOR TABLES IN SCHEMA` publications.
- `two_phase` subscription option.
- `disable_on_error` subscription option.
- `ALTER SUBSCRIPTION ... SKIP (lsn = ...)`.
- `pg_stat_subscription_stats` (apply/sync error counts).
- Subscription owner privilege checks tightened.

## PostgreSQL 16: logical decoding on standbys, parallel apply, origin filtering

- **Logical decoding on physical standbys**.
- **Parallel apply** of large streamed transactions (`streaming = parallel`, `max_parallel_apply_workers_per_subscription`).
- `origin = none`: loop prevention for bidirectional setups.
- Subscriber can use **non-PK B-tree indexes** for `REPLICA IDENTITY FULL` lookups.
- Initial table sync in **binary** format when `binary = true`.
- `pg_create_subscription` predefined role; `password_required`, `run_as_owner` options; apply runs as table owner.

## PostgreSQL 17: failover slots, pg_createsubscriber, slot preservation in pg_upgrade

- **Failover slots**: `failover` option, `sync_replication_slots`, `synchronized_standby_slots`, slotsync worker.
- **`pg_createsubscriber`**: convert a physical standby to a logical subscriber.
- **`pg_upgrade` preserves** logical slots (publisher) and subscriptions (subscriber) when upgrading from PG 17+.
- Hash indexes usable for `REPLICA IDENTITY FULL` lookups on the subscriber.
- `pg_replication_slots.invalidation_reason`, `inactive_since`.
- `pg_stat_subscription.worker_type`.

## PostgreSQL 18: further additions (verify against release notes)

- **Conflict detection, logging and statistics**: named conflict types (`insert_exists`, `update_missing`, `delete_missing`, `*_origin_differs`, …) logged and counted in `pg_stat_subscription_stats`.
- **Stored generated columns** can be published (`publish_generated_columns`).
- `idle_replication_slot_timeout`: invalidate long-idle slots.
- `max_active_replication_origins`: separate from `max_replication_slots` on subscribers.
- Default `streaming` for new subscriptions changed to `parallel`.
- `two_phase` can be changed with `ALTER SUBSCRIPTION`.
- `pg_createsubscriber` additions (`--all`, `--clean`).

Check the official [PostgreSQL 18 release notes](https://www.postgresql.org/docs/18/release-18.html) for the complete and authoritative list.

**PostgreSQL 19** (2026): includes **sequence replication** (`FOR ALL SEQUENCES` publications, `ALTER SUBSCRIPTION ... REFRESH SEQUENCES`) among other logical replication changes. Verify against the [release notes](https://www.postgresql.org/docs/release/) for your version.
