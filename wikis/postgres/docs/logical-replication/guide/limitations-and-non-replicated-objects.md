# Limitations and non-replicated objects

Logical replication replicates **row changes to ordinary tables**. Everything else is your responsibility.

| Object / operation | Replicated? | What to do |
|---|---|---|
| `INSERT` / `UPDATE` / `DELETE` | Yes | n/a |
| `TRUNCATE` | Yes (PG 11+) | Exclude with `publish` if unwanted |
| DDL (`CREATE`, `ALTER`, `DROP`) | **No** | Apply manually on both sides |
| Sequences | **No** (before PG 19) | Sync `setval()` at cutover |
| Large objects (`pg_largeobject`) | **No** | Use `bytea`, or copy separately |
| Materialized views | **No** | Create and refresh on the subscriber |
| Views | **No** (no data to replicate) | Create via schema dump |
| Foreign tables | **No** | Recreate FDW config |
| Unlogged / temporary tables | **No** (not in WAL) | n/a |
| Roles, grants, tablespaces | **No** (cluster-level) | `pg_dumpall --globals-only` |
| Extensions | **No** | Install on subscriber |
| Stored generated columns | Subscriber computes them; publishable from PG 18 | See below |

## DDL

Schema changes are **not** replicated. The subscriber must have compatible tables before data arrives.

- Get the initial schema with `pg_dump --schema-only` (or `--section=pre-data` then `post-data` after the initial copy, so indexes are built after loading).
- Apply every later DDL change on **both** sides, in the right order. See [Operational procedures › Handling DDL changes safely](operational-procedures.md#handling-ddl-changes-safely).
- Mismatches surface as apply errors on the subscriber:

```text
ERROR:  logical replication target relation "app.orders" is missing replicated column: "discount"
```

Columns are matched **by name**, not position. The subscriber can have **extra columns** (filled with defaults) and can use **different but compatible types** (values are converted via text input unless `binary = true`).

## Sequences

Sequence values (`nextval`) are not replicated. Rows arrive with the values generated on the publisher (e.g. `id = 1052`), but the subscriber's sequence stays at its starting value.

Consequences:

- Read-only subscribers: no problem.
- **At cutover** (subscriber becomes the writer), the first `INSERT` gets `id = 1` and fails with a duplicate key, or worse, succeeds where there's no unique constraint.

Fix by syncing sequences just before switching writes. See [Operational procedures › Sequence synchronisation at cutover](operational-procedures.md#sequence-synchronisation-at-cutover).

PG 19 adds sequence support to logical replication (`FOR ALL SEQUENCES` publications and `ALTER SUBSCRIPTION ... REFRESH SEQUENCES`). Verify the details against the [PG 19 release notes](https://www.postgresql.org/docs/release/) before relying on it.

## Large objects

Large objects (`lo_create`, `lo_import`, stored in `pg_largeobject`) are **not** replicated. `pg_largeobject` is a system catalog.

Options:

- Migrate large objects with `pg_dump --large-objects` (`-b`) separately, at cutover.
- Better, convert the application to `bytea` columns, which replicate normally.

```sql
SELECT count(*), pg_size_pretty(pg_total_relation_size('pg_largeobject')) FROM pg_largeobject_metadata;
```

## Materialized views

Materialized views are not tables and are not published. Create them on the subscriber from the schema dump and `REFRESH MATERIALIZED VIEW` there on whatever schedule you need. The subscriber builds them from its replicated base tables.

## Views, foreign tables, and unlogged / temporary tables

- **Views**: hold no data. Create them on the subscriber via the schema dump.
- **Foreign tables**: data lives elsewhere. Recreate the server, user mapping and foreign table definitions on the subscriber.
- **Unlogged tables**: not WAL-logged, so logical decoding never sees changes. They can't be added to a publication. Copy the data manually if needed, or `ALTER TABLE ... SET LOGGED`.
- **Temporary tables**: session-local, never replicated.

## Truncate behaviour

- `TRUNCATE` is replicated since **PG 11** if `truncate` is in the publication's `publish` list (default).
- If the truncated table is referenced by foreign keys on the **subscriber** from tables that are not part of the same subscription, the truncate fails on the subscriber. Tables truncated together on the publisher (e.g. with `CASCADE`) are truncated together on the subscriber if they are all subscribed.
- `TRUNCATE` of a partitioned table propagates according to `publish_via_partition_root`.
- To protect a subscriber (e.g. an archive) from accidental wipes, publish without `truncate`:

```sql
ALTER PUBLICATION pub_archive SET (publish = 'insert, update, delete');
```

## Generated columns

- **Stored generated columns** (`GENERATED ALWAYS AS (...) STORED`):
    - **Before PG 18**: not published. The subscriber computes them itself, so the subscriber column must also be a generated column (or a normal column you populate another way).
    - **PG 18+**: can be published with `publish_generated_columns = stored` on the publication (or by naming them in a column list). The subscriber column must then be a normal column; replicating into a generated column is an error.
- **Virtual generated columns** (PG 18+): never published; they are computed on read.
- **Identity columns** (`GENERATED ... AS IDENTITY`): replicated as normal values. The underlying sequence is not replicated (see [Sequences](#sequences)).

## Schema drift between publisher and subscriber

Over time the two sides diverge unless you control DDL carefully. Typical drift:

- Column added on the publisher only → apply errors ("missing replicated column").
- Column dropped on the subscriber only → same error.
- `NOT NULL` or `CHECK` constraint on the subscriber that the publisher doesn't enforce → apply errors on violating rows.
- Unique index on the subscriber only → duplicate key conflicts.
- Different column types → conversion errors.

Detect it periodically by diffing schemas:

```bash
pg_dump --schema-only --no-owner --no-privileges -d "$PUB_URL" > pub.sql
pg_dump --schema-only --no-owner --no-privileges -d "$SUB_URL" > sub.sql
diff -u pub.sql sub.sql
```

Or use a schema diff tool (`migra`, `pgquarrel`, Flyway/Liquibase validation). Running the same migration tool against both sides keeps them in step.

## Changes by PostgreSQL version

| Limitation | Lifted in |
|---|---|
| `TRUNCATE` not replicated | PG 11 |
| Partitioned tables can't be published / subscribed to | PG 13 |
| Large transactions only sent at commit | PG 14 (`streaming`) |
| No row/column filtering, no schema-level publications | PG 15 |
| No way to skip a failing transaction | PG 15 (`SKIP`) |
| `REPLICA IDENTITY FULL` always seq-scans on subscriber | PG 16 (index use) |
| No logical decoding from standbys | PG 16 |
| No loop prevention for bidirectional replication | PG 16 (`origin = none`) |
| Slots lost on physical failover | PG 17 (failover slots) |
| Slots / subscriptions lost by `pg_upgrade` | PG 17 |
| Stored generated columns not publishable | PG 18 |
| Sequences not replicated | PG 19 (verify) |

See [Version history](version-history.md) for detail.
