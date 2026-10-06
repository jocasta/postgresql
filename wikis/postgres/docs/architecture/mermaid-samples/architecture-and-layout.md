# Architecture & Layout

## Architecture diagram (architecture-beta)

Built-in icons: `cloud`, `database`, `disk`, `internet`, `server`.

```mermaid
architecture-beta
    group vpc(cloud)[VPC]
    group dbsub(cloud)[DB subnet] in vpc

    service users(internet)[Users]
    service app(server)[App servers] in vpc
    service pgb(server)[PgBouncer] in vpc
    service primary(database)[Primary] in dbsub
    service replica(database)[Replica] in dbsub
    service backups(disk)[WAL archive]

    users:R --> L:app
    app:R --> L:pgb
    pgb:R --> L:primary
    primary:B --> T:replica
    primary:R --> L:backups
```

## Block diagram (block-beta)

```mermaid
block-beta
    columns 3
    app["Application"]:3
    space:3
    pgb1["PgBouncer A"] space pgb2["PgBouncer B"]
    space:3
    primary[("Primary")] space replica[("Replica")]

    app --> pgb1
    app --> pgb2
    pgb1 --> primary
    pgb2 --> primary
    primary -- "WAL" --> replica
```

## Packet diagram (packet-beta) — heap page header

The 24-byte `PageHeaderData` at the start of every 8 KB page.

```mermaid
packet-beta
    title PostgreSQL page header (24 bytes)
    0-63: "pd_lsn"
    64-79: "pd_checksum"
    80-95: "pd_flags"
    96-111: "pd_lower"
    112-127: "pd_upper"
    128-143: "pd_special"
    144-159: "pd_pagesize_version"
    160-191: "pd_prune_xid"
```

## Mind map — performance troubleshooting

```mermaid
mindmap
  root((Slow database))
    Queries
      pg_stat_statements
      auto_explain
      Missing indexes
    Locks
      pg_locks
      Long transactions
    I/O
      pg_stat_io
      Checkpoints
      shared_buffers hit ratio
    Maintenance
      Autovacuum lag
      Bloat
        pgstattuple
        pg_repack
    Connections
      max_connections
      PgBouncer
```
