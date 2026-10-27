# Subscriptions

## Creating and altering subscriptions

Prerequisites on the subscriber:

- The **tables must already exist** with compatible columns (matched by schema-qualified name and column name; extra columns on the subscriber are allowed).
- Usually: `pg_dump --schema-only` from the publisher and restore it.

```sql
CREATE SUBSCRIPTION sub_app
    CONNECTION 'host=pub.example.com port=5432 dbname=app user=repl password=... sslmode=require'
    PUBLICATION pub_app;
```

What happens:

1. Connects to the publisher and checks the publications exist.
2. Creates a logical slot named after the subscription (`sub_app`) with `pgoutput`.
3. Records the published tables in `pg_subscription_rel`.
4. Starts the apply worker, which starts tablesync workers for the initial copy.

Altering:

```sql
ALTER SUBSCRIPTION sub_app CONNECTION 'host=new-pub.example.com dbname=app user=repl';
ALTER SUBSCRIPTION sub_app SET PUBLICATION pub_app, pub_extra;      -- replaces list, refreshes
ALTER SUBSCRIPTION sub_app ADD PUBLICATION pub_extra;
ALTER SUBSCRIPTION sub_app DROP PUBLICATION pub_extra;
ALTER SUBSCRIPTION sub_app SET (streaming = parallel, disable_on_error = true);
ALTER SUBSCRIPTION sub_app OWNER TO repl_admin;
```

!!! tip
    Avoid putting passwords in `CONNECTION`: they are visible in `pg_subscription.subconninfo` to superusers. Use a `~/.pgpass` file for the postgres OS user on the subscriber, or certificate authentication.

## copy_data, create_slot, enabled, slot_name options

| Option | Default | Meaning |
|---|---|---|
| `copy_data` | `true` | Copy existing rows with `COPY` before streaming changes. Set `false` if the data is already there (e.g. restored from a dump at a known LSN). |
| `create_slot` | `true` | Create the slot on the publisher. Set `false` to use an existing slot. |
| `slot_name` | subscription name | Name of the publisher slot. `NONE` detaches the subscription from any slot. |
| `enabled` | `true` | Start replicating immediately. |
| `connect` | `true` | Connect to the publisher at create time. `false` implies `create_slot = false`, `copy_data = false`, `enabled = false`. |
| `streaming` | `off` (`parallel` in PG 18+) | Stream large in-progress transactions: `off`, `on`, `parallel` (PG 16+). |
| `binary` | `false` | Use binary format for data transfer. |
| `synchronous_commit` | `off` | `synchronous_commit` used by the apply worker. |
| `two_phase` | `false` | Replicate prepared transactions at `PREPARE` time (PG 15+). |
| `disable_on_error` | `false` | Disable the subscription instead of retrying in a loop on error (PG 15+). |
| `origin` | `any` | `none` = only receive changes that originated on the publisher (PG 16+). |
| `password_required` | `true` | Require password authentication for non-superuser owners (PG 16+). |
| `run_as_owner` | `false` | Apply changes as subscription owner instead of table owner (PG 16+). |
| `failover` | `false` | Make the publisher slot a failover slot, synced to standbys (PG 17+). |

```sql
-- data already loaded, slot pre-created, start later
CREATE SUBSCRIPTION sub_app
    CONNECTION '...'
    PUBLICATION pub_app
    WITH (copy_data = false, create_slot = false, slot_name = 'sub_app_slot', enabled = false);

ALTER SUBSCRIPTION sub_app ENABLE;
```

!!! note
    `synchronous_commit = off` for the apply worker is safe: if the subscriber crashes, it simply re-requests from its last flushed position. Leaving it `off` improves apply throughput.

## Refreshing a subscription after publication changes

Adding tables to a publication is **not** picked up automatically:

```sql
-- on publisher
ALTER PUBLICATION pub_app ADD TABLE app.invoices;

-- on subscriber (after creating app.invoices there)
ALTER SUBSCRIPTION sub_app REFRESH PUBLICATION;                       -- copies data for new tables
ALTER SUBSCRIPTION sub_app REFRESH PUBLICATION WITH (copy_data = false);
```

- New tables are added to `pg_subscription_rel` and synced.
- Tables **removed** from the publication are removed from the subscription (their data stays on the subscriber).
- `REFRESH PUBLICATION` can't run inside a transaction block.
- With `FOR ALL TABLES` / `TABLES IN SCHEMA`, new tables on the publisher still need creating on the subscriber **and** a refresh.

## Connecting to existing slots (pre-created slots)

Used when you need the slot to exist **before** the subscriber is ready, e.g. to capture an LSN for a dump/restore or snapshot-based initial load:

```sql
-- publisher
SELECT * FROM pg_create_logical_replication_slot('sub_app_slot', 'pgoutput');

-- subscriber
CREATE SUBSCRIPTION sub_app
    CONNECTION '...'
    PUBLICATION pub_app
    WITH (create_slot = false, slot_name = 'sub_app_slot', copy_data = false);
```

!!! warning
    The slot starts retaining WAL from the moment it is created. Don't leave a pre-created slot unconsumed for long.

A common pattern to start from a known point without `COPY` (e.g. for very large databases):

1. Create the slot on the publisher (or restore a snapshot of the publisher).
2. Load data on the subscriber consistent with that slot's position.
3. Create the subscription with `create_slot = false, copy_data = false, enabled = false`.
4. If needed, advance the origin to the right LSN with `pg_replication_origin_advance('pg_<subid>', '<lsn>')`.
5. Enable the subscription.

Getting step 2 exactly right is hard; `pg_createsubscriber` (PG 17+) automates this for the "start from a physical standby" case. See [Migration and upgrade patterns](migration-and-upgrade-patterns.md#pg_createsubscriber).

## Binary mode

```sql
ALTER SUBSCRIPTION sub_app SET (binary = true);
```

- Data is sent in each type's **binary** send/receive format instead of text.
- Faster for some types (`bytea`, numeric arrays, timestamps, geometry), less CPU for parsing.
- Requires matching binary representations: same types on both sides and compatible versions. Arrays and composites need element types with binary I/O.
- PG 16+ also uses binary format for the **initial `COPY`** when `binary = true`.
- If it fails with type errors, fall back to `binary = false`.

## Subscription ownership, privileges, and password_required

Who can create a subscription:

- **Superuser**, or
- **PG 16+**: a role with membership in `pg_create_subscription` **and** `CREATE` privilege on the database.

Who the changes are applied as:

- **Before PG 16**: as the **subscription owner** (often a superuser).
- **PG 16+**: by default as the **table owner**; the subscription owner must be able to `SET ROLE` to each table owner. `run_as_owner = true` restores the old behaviour.

`password_required` (PG 16+):

- If the owner is not a superuser, the connection to the publisher **must use a password** (prevents a non-superuser using the server's own credentials, e.g. trust/peer auth or `.pgpass`, to connect).
- Only a superuser can set `password_required = false`.

## Disabling, dropping, and slot cleanup

```sql
ALTER SUBSCRIPTION sub_app DISABLE;    -- stop apply; slot keeps retaining WAL!
ALTER SUBSCRIPTION sub_app ENABLE;

DROP SUBSCRIPTION sub_app;             -- also drops the publisher slot (connects to publisher)
```

`DROP SUBSCRIPTION` connects to the publisher to drop the slot. If the publisher is **gone or unreachable**:

```sql
ALTER SUBSCRIPTION sub_app DISABLE;
ALTER SUBSCRIPTION sub_app SET (slot_name = NONE);
DROP SUBSCRIPTION sub_app;
```

Then, if the publisher still exists, drop the orphaned slot there:

```sql
SELECT pg_drop_replication_slot('sub_app');
```

!!! danger
    A **disabled** subscription or an orphaned slot keeps holding WAL on the publisher until the disk fills. Always check `pg_replication_slots` after disabling or dropping subscriptions. See [Replication slots](replication-slots.md).

Tablesync workers also create short-lived slots named like `pg_<subid>_sync_<relid>_<sysid>`. They are normally cleaned up automatically, but can be left behind if a sync is interrupted. Drop them if the subscription no longer exists.
