Absolutely. Monitoring the progress is crucial because the "initial sync" (the snapshot phase) can take a long time for a massive table. You can't just look at a progress bar, but you can query specific system views to see exactly what Postgres is doing.

The primary view you'll use is `pg_stat_replication` on the **publisher** and `pg_stat_subscription_stats` (or `pg_subscription_rel`) on the **subscriber**.

---

## 1. Monitoring the Initial Copy (Subscriber Side)

While the table is physically copying data, Postgres tracks the state of each relation (table) in the `pg_subscription_rel` table.

```sql
SELECT 
    subname, 
    relid::regclass AS table_name, 
    state, 
    latest_end_lsn 
FROM pg_subscription_rel 
JOIN pg_subscription ON pg_subscription.oid = pg_subscription_rel.srsubid;

```

**What the `state` codes mean:**

* **`i` (Initialize):** Just starting up.
* **`d` (Data copy):** The bulk data is currently being streamed.
* **`s` (Synced):** The initial copy is done, and it’s now keeping up with live changes.
* **`r` (Ready):** Fully synchronized and part of normal replication.

---

## 2. Checking Real-Time Throughput (Publisher Side)

To see how fast data is moving and if there is "lag" between the old table and the new partitioned one, query the publisher:

```sql
SELECT 
    application_name, 
    state, 
    sent_lsn, 
    write_lsn, 
    flush_lsn, 
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replication_lag_bytes
FROM pg_stat_replication;

```

> **Note:** `replication_lag_bytes` tells you how far "behind" the new table is. During the initial copy, this number might look huge or static; it becomes most useful once the state flips to `streaming`.

---

## 3. Estimating Completion Time

Postgres doesn't provide a native "Estimated Time Remaining" column. To get a rough idea, you can compare the current row count of your partitioned table against the source:

```sql
-- Run this on the subscriber (new table)
SELECT 
    schemaname, 
    relname, 
    n_live_tup 
FROM pg_stat_user_tables 
WHERE relname = 'your_new_partitioned_table';

```

By checking this every 10 minutes, you can calculate your **rows-per-second** migration rate.

---

## Important Performance Tip

During the `d` (data copy) phase, Postgres is essentially doing a massive `COPY` command. If you have **heavy indexes** or **foreign keys** on the new partitioned table, the copy will be significantly slower.

> **Pro-Tip:** Some engineers prefer to create the partitions **without** indexes, let the logical replication finish the initial copy, build the indexes concurrently, and *then* let it start the catch-up (streaming) phase. This can save hours on a multi-terabyte table.

Would you like me to show you how to check for **conflicts** or **errors** in the Postgres logs if the copy gets stuck?