# Auxiliary processes

| Process | `backend_type` | Job |
|---|---|---|
| Checkpointer | `checkpointer` | Performs checkpoints: flushes all dirty buffers, writes checkpoint record, updates `pg_control` |
| Background writer | `background writer` | Trickles dirty buffers to disk ahead of clock-sweep so backends find clean buffers |
| WAL writer | `walwriter` | Flushes WAL buffers to disk every `wal_writer_delay` (200 ms) — matters for async commits |
| Autovacuum launcher | `autovacuum launcher` | Decides which databases need work and starts workers |
| Autovacuum workers | `autovacuum worker` | Run VACUUM / ANALYZE on individual tables (`autovacuum_max_workers`, default 3) |
| WAL sender | `walsender` | Streams WAL to a standby or logical subscriber, one per connection |
| WAL receiver | `walreceiver` | On a standby: receives WAL from the primary and writes it to `pg_wal` |
| Startup | `startup` | Replays WAL during crash recovery and continuously on a standby |
| Archiver | `archiver` | Runs `archive_command` / `archive_library` for completed WAL segments |
| Logical replication launcher | `logical replication launcher` | Starts apply workers for subscriptions |
| Logical replication workers | `logical replication worker` | Apply changes; tablesync workers do the initial copy |
| WAL summarizer | `walsummarizer` | PG17+: tracks changed blocks for incremental backup (`summarize_wal`) |
| Slot sync worker | `slotsync worker` | PG17+: syncs failover logical slots to a standby |
| I/O workers | `io worker` | PG18+: perform async I/O when `io_method = worker` |
| Parallel workers | `parallel worker` | Helper processes for a parallel query |
| Syslogger | (not in view) | Collects stderr into log files when `logging_collector = on` |
