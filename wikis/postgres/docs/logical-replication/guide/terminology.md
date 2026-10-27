# Terminology

## Publisher and subscriber

- **Publisher**: the database (node) that *sends* changes. It holds the publications and the replication slots.
- **Subscriber**: the database that *receives* and applies changes. It holds the subscriptions and replication origins.

A single database can be both, publishing some tables while subscribing to others. Roles are per database, not per cluster: a subscription connects to one specific database on the publisher.

## Publication

A named set of tables (plus options) whose changes are made available for replication. It lives in the publisher database.

```sql
CREATE PUBLICATION pub_orders FOR TABLE sales.orders, sales.order_lines;
```

- Defines **which tables**, optionally **which rows** (row filter) and **which columns** (column list).
- Defines **which operations** are published (`insert`, `update`, `delete`, `truncate`).
- Does nothing on its own. It is only a filter applied when a subscriber connects.

Catalog: `pg_publication`, `pg_publication_rel`, `pg_publication_namespace`, view `pg_publication_tables`.

See [Publications](publications.md).

## Subscription

A named connection from a subscriber database to one or more publications on a publisher.

```sql
CREATE SUBSCRIPTION sub_orders
    CONNECTION 'host=pub.example.com dbname=app user=repl'
    PUBLICATION pub_orders;
```

- Creates (by default) a logical replication slot on the publisher.
- Starts an apply worker and tablesync workers on the subscriber.
- Stored in `pg_subscription` (cluster-wide catalog, but each subscription belongs to one database), with per-table state in `pg_subscription_rel`.

See [Subscriptions](subscriptions.md).

## Replication slot (logical vs physical)

A **replication slot** is a publisher-side object that remembers how far a consumer has got, so the server **keeps the WAL** (and, for logical slots, the catalog rows) that the consumer still needs.

| | Physical slot | Logical slot |
|---|---|---|
| Used by | Streaming standbys, `pg_basebackup` | Logical replication, CDC tools |
| Scope | Whole cluster | One database |
| Output | Raw WAL | Decoded changes via an output plugin |
| Holds back | WAL (`restart_lsn`), optionally `xmin` via `hot_standby_feedback` | WAL (`restart_lsn`) and catalog rows (`catalog_xmin`) |
| Created by | `pg_create_physical_replication_slot()` | `pg_create_logical_replication_slot()` or `CREATE SUBSCRIPTION` |

```sql
SELECT slot_name, slot_type, plugin, database, active
FROM pg_replication_slots;
```

See [Replication slots](replication-slots.md).

## Replica identity

The set of columns used to identify a row for `UPDATE` and `DELETE`. Their **old values** are written to WAL so the subscriber can find the row to change.

Modes: `DEFAULT` (primary key), `USING INDEX`, `FULL`, `NOTHING`.

See [Replica identity](replica-identity.md).

## Output plugin

A shared library loaded by logical decoding that converts decoded changes into an output format. Built-in replication uses `pgoutput`; others include `test_decoding` and `wal2json`. The plugin is fixed at slot creation time.

## LSNs: confirmed_flush_lsn, restart_lsn, catalog_xmin

An **LSN** (Log Sequence Number) is a position in the WAL stream, shown as e.g. `16/B374D848`. The difference between two LSNs is a number of bytes:

```sql
SELECT pg_current_wal_lsn(),
       pg_wal_lsn_diff(pg_current_wal_lsn(), '16/B0000000') AS bytes_since;
```

Key fields in `pg_replication_slots` for a logical slot:

| Column | Meaning |
|---|---|
| `restart_lsn` | Oldest WAL position the slot may still need to read. WAL from here on **cannot be removed**. Usually behind `confirmed_flush_lsn` because decoding has to restart at the beginning of the oldest transaction still in progress. |
| `confirmed_flush_lsn` | Position up to which the subscriber has **confirmed** it has received and flushed changes. Decoding resumes from here. The gap to `pg_current_wal_lsn()` is the replication lag in bytes. |
| `catalog_xmin` | Oldest transaction ID whose **catalog** rows must be kept for decoding. Holds back vacuum of system catalogs. |
| `xmin` | Not used by logical slots (NULL). |

```text
 WAL ──────────────────────────────────────────────────────────────►
        ▲ restart_lsn           ▲ confirmed_flush_lsn       ▲ pg_current_wal_lsn()
        │ (WAL retained from    │ (subscriber has           │ (latest WAL
        │  here onwards)        │  this much)               │  written)
        └── retained WAL ───────┴──── lag in bytes ─────────┘
```

## Replication origin

A subscriber-side object that tracks **how far changes from a given source have been applied** (`remote_lsn`) and tags locally written WAL with the source. Each subscription has one named `pg_<subid>`.

```sql
SELECT * FROM pg_replication_origin_status;
```

Used for crash-safe restart of apply and for `origin = none` loop prevention.
