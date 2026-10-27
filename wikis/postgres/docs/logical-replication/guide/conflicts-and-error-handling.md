# Conflicts and error handling

A **conflict** happens when the apply worker can't apply a change cleanly on the subscriber. Usually this is because the subscriber's data has diverged (local writes, manual fixes, partial resync) or the schemas differ.

## Types of conflict (unique violation, missing row, etc.)

| Conflict | Example | Default behaviour |
|---|---|---|
| **Unique / PK violation on INSERT** | Row with `id = 42` already exists on the subscriber | **Error**: apply stops and retries |
| **Unique violation on UPDATE** | Updated value collides with an existing row | **Error** |
| **UPDATE of missing row** | Row to update not found by replica identity | **Skipped silently** (logged in PG 18+) |
| **DELETE of missing row** | Row to delete not found | **Skipped silently** (logged in PG 18+) |
| **Constraint violation** | `CHECK` / `NOT NULL` / FK on subscriber only | **Error** |
| **Schema mismatch** | Missing table/column, type conversion failure | **Error** |
| **Permission failure** | Apply role can't write to the table | **Error** |

PG 18 names these conflict types in the logs and statistics:

| PG 18 conflict type | Meaning |
|---|---|
| `insert_exists` | Inserted row violates a unique constraint |
| `update_exists` | Updated row violates a unique constraint |
| `update_missing` | Row to update not found |
| `delete_missing` | Row to delete not found |
| `update_origin_differs` | Row being updated was last modified by a different origin (needs `track_commit_timestamp = on`) |
| `delete_origin_differs` | Row being deleted was last modified by a different origin (needs `track_commit_timestamp = on`) |
| `multiple_unique_conflicts` | Insert/update violates several unique constraints |

!!! warning
    "Missing row" conflicts are **silent** in older versions: the subscriber quietly diverges. Periodic row-count or checksum comparisons are the only way to notice.

## Diagnosing a stuck apply worker

Symptoms: lag growing, `pg_stat_subscription` shows no recent `last_msg_receipt_time` or the worker keeps restarting, and the subscriber log repeats:

```text
ERROR:  duplicate key value violates unique constraint "orders_pkey"
DETAIL:  Key (id)=(42) already exists.
CONTEXT:  processing remote data for replication origin "pg_16405" during message type "INSERT"
          for replication target relation "app.orders" in transaction 778123, finished at 3/A1B2C3D4
LOG:  background worker "logical replication apply worker" (PID 2101) exited with exit code 1
```

Steps:

1. **Read the subscriber log**: the `CONTEXT` line gives the table, origin, remote transaction ID and **finish LSN**.
2. Check error counters:

    ```sql
    SELECT subname, apply_error_count, sync_error_count, stats_reset
    FROM pg_stat_subscription_stats;
    ```

3. Check the worker:

    ```sql
    SELECT subname, pid, received_lsn, latest_end_lsn, last_msg_receipt_time
    FROM pg_stat_subscription;
    ```

4. Decide how to fix it:
    - **Fix the data** on the subscriber (e.g. delete the conflicting row if the publisher's version is authoritative). The worker retries automatically and continues.
    - **Fix the schema** (add the missing column / table) and let it retry.
    - **Skip** the whole remote transaction (below), if you accept losing it.

Prefer fixing the data: skipping loses the **whole** transaction, not just the conflicting row.

## Skipping a transaction (ALTER SUBSCRIPTION ... SKIP)

PG 15+. Skip one remote transaction by its **finish LSN** (from the log `CONTEXT`, "finished at ..."):

```sql
ALTER SUBSCRIPTION sub_app SKIP (lsn = '3/A1B2C3D4');
```

- Only skips the transaction that finishes at exactly that LSN; cleared automatically after use.
- Requires superuser (or subscription owner in newer versions).
- The skipped transaction's changes for **all tables** are lost. Repair the subscriber data afterwards if needed.

Before PG 15 the workaround was to advance the replication origin past the failing transaction:

```sql
ALTER SUBSCRIPTION sub_app DISABLE;
SELECT pg_replication_origin_advance('pg_16405', '3/A1B2C3D5');  -- LSN just after the failing commit
ALTER SUBSCRIPTION sub_app ENABLE;
```

## disable_on_error

PG 15+. By default the apply worker retries a failing change in a loop (with `wal_retrieve_retry_interval` between attempts), filling the log.

```sql
ALTER SUBSCRIPTION sub_app SET (disable_on_error = true);
```

- On error, the subscription is **disabled** instead (`pg_subscription.subenabled = false`).
- Stops log spam, and makes failures visible to monitoring that checks `subenabled`.
- **The slot on the publisher keeps retaining WAL** while disabled, so alert on it promptly.

```sql
SELECT subname, subenabled FROM pg_subscription WHERE NOT subenabled;
```

## Conflict logging and resolution in newer versions

- **PG 15**: `pg_stat_subscription_stats` with `apply_error_count`, `sync_error_count`.
- **PG 18**: conflicts are detected and **logged** with their type, including previously silent ones (`update_missing`, `delete_missing`), and counted per type in `pg_stat_subscription_stats` (`confl_insert_exists`, `confl_update_missing`, …). Origin-differs detection needs `track_commit_timestamp = on` on the subscriber.

```sql
-- PG 18+
SELECT subname, confl_insert_exists, confl_update_exists, confl_update_missing,
       confl_delete_missing, confl_update_origin_differs, confl_delete_origin_differs
FROM pg_stat_subscription_stats;
```

Automatic conflict **resolution** (e.g. last-update-wins) is not part of core PostgreSQL as of PG 18; it is being worked on for later releases. Extensions such as **pglogical** and commercial multi-master products (pgEdge, EDB PGD) provide resolution strategies.

## Recovering from divergence

If the subscriber has drifted (silent missing-row skips, manual writes, skipped transactions), options from least to most work:

1. **Repair specific rows**: compare the affected table on both sides and fix the differences.

    ```sql
    -- quick row-count and checksum comparison, run on both sides
    SELECT count(*), md5(string_agg(t::text, '|' ORDER BY id)) FROM app.orders t;
    ```

    For big tables, compare in key ranges (`WHERE id BETWEEN ...`) to narrow down.

2. **Resync one table**: see [Operational procedures › Resynchronising a single table](operational-procedures.md#resynchronising-a-single-table).

3. **Rebuild the subscription**: drop the subscription, truncate the subscriber tables, recreate with `copy_data = true`.

Prevent divergence by making the subscriber **read-only for replicated tables** (revoke write privileges from application roles), so only the apply worker writes there.
