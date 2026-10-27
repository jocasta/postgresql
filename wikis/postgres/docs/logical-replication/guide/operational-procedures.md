# Operational procedures

## Setting up logical replication step by step

**1. Publisher configuration** (restart required):

```sql
ALTER SYSTEM SET wal_level = 'logical';
ALTER SYSTEM SET max_replication_slots = 16;
ALTER SYSTEM SET max_wal_senders = 16;
ALTER SYSTEM SET max_slot_wal_keep_size = '100GB';
```

**2. Replication role on the publisher:**

```sql
CREATE ROLE repl WITH LOGIN REPLICATION PASSWORD '...';
GRANT USAGE ON SCHEMA app TO repl;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO repl;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT ON TABLES TO repl;
```

**3. `pg_hba.conf` on the publisher** (match the **database name**, not `replication`):

```text
hostssl  app  repl  10.0.0.0/16  scram-sha-256
```

**4. Check replica identity** for every table to be published. See [Replica identity](replica-identity.md#checking-and-changing-replica-identity). Fix any table without a PK.

**5. Create the publication:**

```sql
CREATE PUBLICATION pub_app FOR TABLES IN SCHEMA app;
```

**6. Copy the schema to the subscriber** (without indexes and constraints for a faster initial load, if the dataset is large):

```bash
pg_dump -h pub -d app --schema-only --section=pre-data  | psql -h sub -d app
# later, after initial sync:
pg_dump -h pub -d app --schema-only --section=post-data | psql -h sub -d app
```

!!! note
    Primary keys, unique constraints and indexes are all in *post-data*, not *pre-data*. Without a PK on the subscriber, `UPDATE`/`DELETE` apply does a sequential scan per row while the initial copy is running. For big, busy tables, create the **primary key** before subscribing and only defer secondary indexes.

**7. Subscriber configuration**: raise `max_logical_replication_workers`, `max_sync_workers_per_subscription` and `max_worker_processes` as needed.

**8. Create the subscription:**

```sql
CREATE SUBSCRIPTION sub_app
    CONNECTION 'host=pub dbname=app user=repl sslmode=require'
    PUBLICATION pub_app
    WITH (streaming = parallel);   -- PG 16+
```

**9. Watch the initial sync** until all tables are `r`:

```sql
SELECT srsubstate, count(*) FROM pg_subscription_rel GROUP BY 1;
```

**10. Add monitoring**: slot retained WAL, subscription enabled, lag. See [Monitoring and troubleshooting](monitoring-and-troubleshooting.md).

**11. Verify data**: row counts and spot checks on both sides.

See also the [Quick Start](../setup-guides/quick-start.md) setup guide.

## Adding and removing tables from a live setup

**Add a table** (with `FOR TABLE` publications):

```sql
-- 1. subscriber: create the table (same definition)
-- 2. publisher:
ALTER PUBLICATION pub_app ADD TABLE app.invoices;
-- 3. subscriber:
ALTER SUBSCRIPTION sub_app REFRESH PUBLICATION;   -- copies existing rows
```

With `TABLES IN SCHEMA` / `ALL TABLES`, a new table is in the publication from the moment it's created. Create it on the **subscriber first**, then the publisher, then refresh, otherwise the apply worker errors on the first change to the unknown table.

**Remove a table:**

```sql
-- publisher
ALTER PUBLICATION pub_app DROP TABLE app.invoices;
-- subscriber
ALTER SUBSCRIPTION sub_app REFRESH PUBLICATION;
-- subscriber: drop or keep the now-static copy
```

## Handling DDL changes safely

Rule of thumb: **make the subscriber able to accept both the old and new shape before the publisher starts producing the new shape.**

| Change | Order | Notes |
|---|---|---|
| Add column | **Subscriber first**, then publisher | Subscriber column must be nullable or have a default |
| Drop column | **Publisher first**, then subscriber | Once the publisher stops sending it, the subscriber column is unused |
| Rename column | Avoid; or add new + backfill + drop old | Columns are matched by name; a rename breaks apply until both sides match |
| Change type (widening, e.g. `int` → `bigint`) | **Subscriber first** | Subscriber must accept all values the publisher can send |
| Add table | Subscriber first, then publisher, then `REFRESH` | n/a |
| Drop table | Remove from publication, `REFRESH`, then drop on both sides | n/a |
| Add index | Either side, independently | Indexes are not replicated |
| Add `NOT NULL` / `CHECK` | **Publisher first** | Otherwise rows that pass on the publisher can fail on the subscriber |

Practical tips:

- Run the **same migration** (Flyway/Liquibase) against both databases, subscriber first for additive changes.
- Pause risky changes: `ALTER SUBSCRIPTION ... DISABLE`, apply DDL on both sides, `ENABLE`. The slot buffers the changes in the meantime.
- See the [Schema Migrations](../../schema-migrations/index.md) section for general online DDL patterns.

## Resynchronising a single table

When one table has diverged and you don't want to rebuild everything:

```sql
-- 1. publisher: remove the table from the publication
ALTER PUBLICATION pub_app DROP TABLE app.orders;

-- 2. subscriber: stop tracking it
ALTER SUBSCRIPTION sub_app REFRESH PUBLICATION;

-- 3. subscriber: empty it
TRUNCATE app.orders;

-- 4. publisher: add it back
ALTER PUBLICATION pub_app ADD TABLE app.orders;

-- 5. subscriber: re-copy
ALTER SUBSCRIPTION sub_app REFRESH PUBLICATION WITH (copy_data = true);
```

!!! warning
    With `TABLES IN SCHEMA` / `ALL TABLES` publications you can't drop a single table. Use a **separate** temporary subscription for that table, or rebuild the subscription. Watch out for FKs on the subscriber referencing the table when truncating (they are usually not needed on a replica).

## Sequence synchronisation at cutover

Sequences are not replicated (before PG 19). Just **before** sending writes to the subscriber, after the publisher is read-only and the subscriber has caught up:

```sql
-- run on PUBLISHER: generates setval() statements to run on the subscriber
SELECT format('SELECT setval(%L, %s, true);',
              quote_ident(schemaname) || '.' || quote_ident(sequencename),
              last_value)
FROM pg_sequences
WHERE last_value IS NOT NULL
ORDER BY schemaname, sequencename;
```

```bash
psql -h pub -d app -At -f gen_setval.sql | psql -h sub -d app
```

- Optionally add a safety gap (`last_value + 1000`) in case anything wrote after you captured the values.
- Run it **after** writes on the publisher have stopped, or the values will already be out of date.
- Sequences that have never been used (`last_value IS NULL`) are skipped.
- Identity columns use sequences too and are covered by `pg_sequences`.

## Failover and switchover considerations

**Publisher fails over (physical HA on the publisher side):**

- **Before PG 17**: the logical slot is not on the standby. After promotion, the subscription can't continue from where it was. You must recreate the slot and **resync** (or accept data loss and find the right LSN manually).
- **PG 17+**: use failover slots (`failover = true`, `sync_replication_slots`, `synchronized_standby_slots`). After promotion, `ALTER SUBSCRIPTION ... CONNECTION` to the new primary (or use a DNS name/VIP so it reconnects automatically). See [Replication slots](replication-slots.md#failover-slots-and-slot-synchronisation-to-standbys).

**Subscriber fails over:**

- Subscriptions and replication origins are in the subscriber's WAL, so a **physical standby of the subscriber** has them after promotion. The promoted subscriber reconnects using the same slot.
- Make sure the old subscriber is really down (two subscribers on one slot would conflict: "slot is active for PID").

**Planned switchover (publisher → subscriber becomes primary):** see [Migration and upgrade patterns › Cutover checklist](migration-and-upgrade-patterns.md#cutover-checklist-and-rollback-plan).

## Backup and restore interactions

- **`pg_dump`** of the publisher includes **publications**. Of the subscriber, it includes **subscriptions**, which are restored **disabled with `connect = false`** (no slot) so a restore doesn't start pulling from production. Use `--no-publications` / `--no-subscriptions` to exclude them.
- **Replication slots are not in `pg_dump`** and are **not copied by `pg_basebackup`**. A restored/cloned publisher has no slots.
- **Restoring a subscriber from a physical backup / snapshot** (or cloning it for test): the restored copy still has the subscription **enabled**, and on startup it will try to connect to the production publisher and take over the slot. Disable it immediately, or start the clone with `max_logical_replication_workers = 0`, then:

    ```sql
    ALTER SUBSCRIPTION sub_app DISABLE;
    ALTER SUBSCRIPTION sub_app SET (slot_name = NONE);
    DROP SUBSCRIPTION sub_app;
    ```

- **PITR on the publisher** loses slots created after the base backup and moves the timeline. Subscribers usually need to resync.
- Logical replication is **not a backup**: deletes and truncates are replicated. Keep normal backups of the subscriber if it holds data you care about.
