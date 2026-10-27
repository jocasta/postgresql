# Publications

## Creating and altering publications

A publication is created in the **publisher database** by the table owner (or a superuser for `ALL TABLES` / `TABLES IN SCHEMA`).

```sql
CREATE PUBLICATION pub_app FOR TABLE app.customers, app.orders;

-- add / remove / replace tables
ALTER PUBLICATION pub_app ADD TABLE app.order_lines;
ALTER PUBLICATION pub_app DROP TABLE app.customers;
ALTER PUBLICATION pub_app SET TABLE app.orders, app.order_lines;

-- change options
ALTER PUBLICATION pub_app SET (publish = 'insert, update, delete');

-- rename / change owner / drop
ALTER PUBLICATION pub_app RENAME TO pub_sales;
ALTER PUBLICATION pub_sales OWNER TO app_owner;
DROP PUBLICATION pub_sales;
```

```sql
-- what is published
SELECT * FROM pg_publication;
SELECT * FROM pg_publication_tables ORDER BY pubname, schemaname, tablename;
```

```text
-- psql
\dRp+
```

!!! note
    After changing the table list, subscribers must run `ALTER SUBSCRIPTION ... REFRESH PUBLICATION` to pick up **added** tables. See [Subscriptions](subscriptions.md#refreshing-a-subscription-after-publication-changes).

## Table, ALL TABLES and TABLES IN SCHEMA publications

| Form | Covers | Future tables | Privilege |
|---|---|---|---|
| `FOR TABLE t1, t2` | Listed tables | No, add them explicitly | Owner of each table |
| `FOR TABLES IN SCHEMA s1, s2` (PG 15+) | All tables in the schemas | **Yes**, new tables in the schema are included automatically | Superuser |
| `FOR ALL TABLES` | Every table in the database | **Yes** | Superuser |

```sql
CREATE PUBLICATION pub_all FOR ALL TABLES;

CREATE PUBLICATION pub_sales FOR TABLES IN SCHEMA sales, billing;

-- mix (PG 15+)
CREATE PUBLICATION pub_mixed FOR TABLES IN SCHEMA sales, TABLE app.customers;
```

!!! warning
    With `ALL TABLES` / `TABLES IN SCHEMA`, any **new table** is published immediately. If it has no primary key, `UPDATE`/`DELETE` on it will fail on the publisher. The subscriber also needs the table created and a `REFRESH PUBLICATION`, or the apply worker errors when the first change arrives.

## Row filters (WHERE)

PG 15+. Only rows matching the filter are replicated.

```sql
CREATE PUBLICATION pub_eu FOR TABLE app.customers WHERE (region = 'EU');
ALTER PUBLICATION pub_eu SET TABLE app.customers WHERE (region IN ('EU', 'UK'));
```

Rules:

- Only simple expressions: no user-defined functions, no subqueries, no non-immutable built-ins.
- If the publication publishes `update` or `delete`, the filter may only reference **replica identity columns**.
- Not allowed with `FOR ALL TABLES` / `TABLES IN SCHEMA` entries (only on `TABLE` entries).
- The initial `COPY` also applies the filter.

How `UPDATE`s that cross the filter boundary are handled:

| Old row matches | New row matches | Sent to subscriber as |
|---|---|---|
| No | No | Nothing |
| No | Yes | `INSERT` |
| Yes | No | `DELETE` |
| Yes | Yes | `UPDATE` |

If a table is in several publications used by one subscription with different filters, the filters are **OR**ed; a publication with no filter for that table means all rows.

## Column lists

PG 15+. Only the listed columns are replicated.

```sql
CREATE PUBLICATION pub_users_min FOR TABLE app.users (id, email, created_at);
```

Rules:

- If the publication publishes `update` or `delete`, the list must include all **replica identity** columns.
- The subscriber table needs at least these columns (it can have more; they get defaults/NULL).
- The initial copy only copies these columns.
- Useful for **data minimisation**: don't send PII columns to an analytics replica.
- One subscription can't combine publications that give the **same table different column lists**; this is reported as an error.

## Choosing published operations (publish = 'insert, update, ...')

```sql
CREATE PUBLICATION pub_audit FOR TABLE app.audit_log WITH (publish = 'insert');
ALTER PUBLICATION pub_app SET (publish = 'insert, update, delete, truncate');  -- default
```

| Value | Effect |
|---|---|
| `insert` | `INSERT`s and `COPY` |
| `update` | `UPDATE`s (needs replica identity) |
| `delete` | `DELETE`s (needs replica identity) |
| `truncate` | `TRUNCATE` (PG 11+) |

Common patterns:

- **Append-only archive**: `publish = 'insert'`. Rows deleted on the publisher (e.g. retention purge) are kept on the subscriber.
- **No truncates downstream**: omit `truncate` so an accidental `TRUNCATE` on the publisher does not wipe the subscriber.

## Partitioned tables and publish_via_partition_root

PG 13+ can publish a **partitioned table**: all its partitions are included, including partitions attached later.

```sql
CREATE PUBLICATION pub_events FOR TABLE app.events
    WITH (publish_via_partition_root = true);
```

| `publish_via_partition_root` | Changes appear on the subscriber as | Use when |
|---|---|---|
| `false` (default) | Changes to each **leaf partition** (`events_2026_10`, …) | Subscriber has the **same partitions** |
| `true` | Changes to the **root** table (`events`) | Subscriber is partitioned differently, or not partitioned at all |

Notes:

- With `true`, the subscriber routes rows into its own partitions (subscriber-side partition routing is PG 13+).
- With `false`, every partition must exist on the subscriber with the same name; new partitions must be created on both sides and the subscription refreshed.
- `TRUNCATE` of the root replicates as truncates of the partitions (or of the root with `true`).
- Before PG 13 you had to publish each partition individually.
