# Performance and tuning

## Publisher-side overhead

| Source of overhead | Impact | Mitigation |
|---|---|---|
| `wal_level = logical` | Small extra WAL (old key values, catalog info) | Keep replica identity to the PK |
| `REPLICA IDENTITY FULL` | Full old row logged per update/delete; large WAL increase | Add primary keys |
| Decoding (walsender CPU) | One walsender per subscription **decodes all WAL** for the database, even for unpublished tables | Fewer subscriptions (combine publications); avoid many subscriptions to the same database |
| Reorder buffer memory / spill | Up to `logical_decoding_work_mem` per walsender, then disk I/O in `pg_replslot/` | Raise `logical_decoding_work_mem`; enable `streaming` |
| Initial `COPY` | Sequential reads of every table; long-running snapshot holds back vacuum | Run off-peak; split large tables across subscriptions or time |
| Retained WAL / catalog_xmin | Disk usage, catalog bloat | Monitor slots; `max_slot_wal_keep_size` |

!!! note
    Each logical walsender reads and decodes the **entire WAL stream** for its database, then discards changes for tables not in its publications. Ten subscriptions on one busy database = ten full decodes. Prefer one subscription per subscriber database with several publications.

## Subscriber apply throughput and bottlenecks

The apply worker is **single-threaded per subscription** for normal (non-streamed) transactions. Its throughput is bounded by how fast one backend can apply rows, typically tens of thousands of rows/s for simple PK-indexed tables, much less with many indexes or triggers.

Bottlenecks and fixes:

| Bottleneck | Symptom | Fix |
|---|---|---|
| Single apply worker | Lag grows under steady load, one CPU core at 100% on subscriber | **Split tables across several subscriptions** (each has its own apply worker and slot); keep tables with FK relationships in the same subscription |
| Too many indexes | Apply slow, I/O heavy | Drop indexes not needed on the subscriber |
| No index for replica identity lookup | Every `UPDATE`/`DELETE` seq-scans | Add PK / unique index on subscriber |
| Locks on subscriber | Apply waits (`wait_event_type = Lock`) | Avoid long reporting queries holding locks; don't run DDL on replicated tables |
| `synchronous_commit` | fsync per applied transaction | Keep subscription `synchronous_commit = off` (default) |
| Slow disk / checkpoints | High WAL write latency on subscriber | Normal write tuning: `max_wal_size`, faster storage |
| Network latency | Lag tracks bandwidth | Compression at network level; place subscriber close to publisher during migration |
| Text format conversion | CPU-bound apply | `binary = true` |

!!! warning
    Splitting into several subscriptions breaks **cross-table transactional consistency** on the subscriber: tables in different subscriptions can be at different points in time. Usually fine for migrations (everything converges at cutover), but not for consistent reporting.

## Large transactions and spill-to-disk

A single large transaction (bulk `UPDATE`, big `DELETE`, data load) affects logical replication in several ways:

1. **Publisher**: the reorder buffer exceeds `logical_decoding_work_mem` and spills to `pg_replslot/<slot>/xid-*.spill` files. Heavy disk I/O, and restarting the walsender means re-decoding from the transaction start.
2. **Lag spike**: without streaming, nothing is sent until commit. Then the subscriber has to apply the whole thing in one transaction.
3. **`restart_lsn` held back** to the start of the oldest open transaction, so WAL retention grows for its duration.

Mitigations:

- `streaming = on` / `parallel` on the subscription (PG 14 / PG 16+).
- Raise `logical_decoding_work_mem` (e.g. `256MB`–`1GB`) if memory allows.
- **Batch** large data changes on the publisher (e.g. delete in chunks of 10k rows, each its own transaction).
- Watch `pg_stat_replication_slots.spill_bytes`.

## Indexes on subscriber tables

- The subscriber only needs **indexes the apply process and subscriber queries use**:
    - The **primary key / replica identity index** (essential for `UPDATE`/`DELETE`).
    - Indexes for reporting queries run on the subscriber.
- Every extra index slows apply (each insert/update maintains it).
- During the **initial copy**, have only the PK (or nothing for insert-only tables); build other indexes after all tables reach `r`, using `CREATE INDEX CONCURRENTLY` if the subscriber is already in use.
- The subscriber **can have different indexes** from the publisher. A reporting replica can have indexes the OLTP primary would never tolerate.

## REPLICA IDENTITY FULL impact on apply

On the subscriber, applying an `UPDATE`/`DELETE` for a `FULL` table means finding a row equal in **every column**:

- **PG 15 and older**: always a **sequential scan** per row changed. One `UPDATE` touching 50,000 rows on a 10M-row table = 50,000 full table scans. Replication effectively stops.
- **PG 16+**: the apply worker can use a **B-tree index** on the subscriber (not partial, first column a plain column) to find candidates, then compare all columns. PG 17 adds hash index support.
- Columns with types lacking an equality operator (e.g. `json`, `point`) can't be compared and cause apply errors.

If a table must stay `FULL`:

- Make sure the **subscriber** has a selective index on it (PG 16+).
- Keep `UPDATE`/`DELETE` volume on it low.
- Better: add a surrogate key (`id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`) on the publisher.

See [Replica identity](replica-identity.md#replica-identity-full-cost-and-trade-offs).
