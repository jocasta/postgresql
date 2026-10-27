# Replica identity

## What it is and why it’s needed

When a row is **updated or deleted** on the publisher, the subscriber has to find the same row in its copy of the table. A row's physical location (`ctid`) means nothing on another server, so PostgreSQL logs the **old values of a set of identifying columns**: the table's *replica identity*.

- `INSERT` needs no replica identity (there is no old row).
- `UPDATE` and `DELETE` do, **if the publication publishes those operations**.
- The replica identity is a property of the **table**, set on the publisher. The subscriber uses the same columns to look up the row.

## The four modes: DEFAULT, USING INDEX, FULL, NOTHING

| Mode | Old values logged | Requirements | Notes |
|---|---|---|---|
| `DEFAULT` | Primary key columns | Table has a primary key | The normal, recommended case. Without a PK this behaves like `NOTHING`. |
| `USING INDEX idx` | Columns of the named index | Unique, non-partial, non-deferrable index on `NOT NULL` columns | For tables with a natural unique key but no PK. |
| `FULL` | **Entire old row** | None | Works for any table; expensive. |
| `NOTHING` | Nothing | None | `UPDATE`/`DELETE` cannot be replicated. Default for system tables. |

```sql
ALTER TABLE app.users REPLICA IDENTITY DEFAULT;
ALTER TABLE app.events REPLICA IDENTITY USING INDEX events_event_uuid_key;
ALTER TABLE app.legacy_log REPLICA IDENTITY FULL;
ALTER TABLE app.scratch REPLICA IDENTITY NOTHING;
```

## Primary key vs unique index requirements

**Primary key (`DEFAULT`)**: simplest and fastest. If a table has a natural key, consider promoting it:

```sql
-- build the index without blocking writes, then attach it as the PK
CREATE UNIQUE INDEX CONCURRENTLY users_pkey_idx ON app.users (id);
ALTER TABLE app.users ADD CONSTRAINT users_pkey PRIMARY KEY USING INDEX users_pkey_idx;
```

**Unique index (`USING INDEX`)**: the index must be:

- `UNIQUE`
- non-partial (no `WHERE` clause)
- non-deferrable
- on columns that are all `NOT NULL`
- not an expression index

On the **subscriber**, the table needs a matching way to look rows up: ideally the same primary key or unique index. The subscriber does not need the same *replica identity setting*, but without a suitable index every `UPDATE`/`DELETE` is a sequential scan.

## REPLICA IDENTITY FULL cost and trade-offs

`FULL` is the fallback for tables with no usable key.

Costs:

- **WAL volume**: every `UPDATE`/`DELETE` logs the whole old row (TOASTed values are included if they changed). This can multiply WAL for wide, frequently updated tables.
- **Subscriber apply**: the apply worker has to find a row matching **all** columns:
    - **Before PG 16**: always a sequential scan per changed row. For a big table this is catastrophic (an `UPDATE` of 10,000 rows = 10,000 full scans).
    - **PG 16+**: the subscriber can use a suitable **B-tree index** (non-partial, whose leading column is a plain column reference) to find candidate rows. PG 17 also allows hash indexes.
- **Duplicates**: if the table contains fully identical rows, only one of them is changed per replicated change. This is usually fine, since each publisher change targets exactly one row.
- Some column types have **no equality operator** (`json`, `point`, …). `FULL` with such columns can fail on the subscriber.

Use `FULL` for small or append-mostly tables; add a key for anything large and frequently updated.

## Behaviour for UPDATE / DELETE without a replica identity

If a table is in a publication that publishes `update`/`delete` and has no usable replica identity (no PK and `DEFAULT`, or `NOTHING`), the **write fails on the publisher**:

```text
ERROR:  cannot update table "device_inbox" because it does not have a replica identity and publishes updates
HINT:  To enable updating the table, set REPLICA IDENTITY using ALTER TABLE.
```

!!! danger
    This breaks your **application** on the publisher, not just replication. Check replica identity for every table **before** adding it to a publication, especially with `FOR ALL TABLES` or `FOR TABLES IN SCHEMA`.

Options:

1. Add a primary key (best).
2. `REPLICA IDENTITY USING INDEX` on an existing unique index.
3. `REPLICA IDENTITY FULL`.
4. Publish only inserts: `WITH (publish = 'insert')` (for append-only tables).

## Partitioned tables and replica identity

- Replica identity is set **per partition** (leaf table), since that is where rows physically live.
- Don't rely on setting it on the partitioned parent (`ALTER TABLE parent REPLICA IDENTITY ...`) to reach every partition. Check each partition with the query below, and set it on new partitions as they are created (e.g. in your `pg_partman` template).
- A primary key on a partitioned table must include the partition key, and is created on each partition, so `DEFAULT` usually works automatically.
- With `publish_via_partition_root = true`, changes are published as if they came from the root table, but each partition still needs a replica identity.

```sql
-- partitions without a usable replica identity
SELECT c.oid::regclass AS partition, c.relreplident
FROM pg_inherits i
JOIN pg_class c ON c.oid = i.inhrelid
WHERE c.relkind = 'r'
  AND (c.relreplident = 'n'
       OR (c.relreplident = 'd'
           AND NOT EXISTS (SELECT 1 FROM pg_index x WHERE x.indrelid = c.oid AND x.indisprimary)));
```

## Checking and changing replica identity

`pg_class.relreplident`: `d` default, `i` index, `f` full, `n` nothing.

```sql
-- tables that will break UPDATE/DELETE if published
SELECT n.nspname AS schema, c.relname AS table_name,
       c.relreplident,
       EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.oid AND i.indisprimary) AS has_pk
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND (c.relreplident = 'n'
       OR (c.relreplident = 'd'
           AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.oid AND i.indisprimary)))
ORDER BY 1, 2;
```

```sql
-- which index is the replica identity index
SELECT indrelid::regclass, indexrelid::regclass
FROM pg_index
WHERE indisreplident;
```

`ALTER TABLE ... REPLICA IDENTITY` takes an `ACCESS EXCLUSIVE` lock briefly but does not rewrite the table.

More queries: [Logical Replication SQL](../sql/logical-replication-queries.md) (*Postgres Replication Identity*, *Inventory of all tables*, *Generate the REPLICA IDENTITY FULL statements*).
