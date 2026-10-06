# Flowcharts

## Replication topology

```mermaid
flowchart LR
    app[Application] --> pgb[PgBouncer]
    pgb -->|read/write| primary[(Primary)]
    pgb -.->|read only| r1[(Replica 1)]
    pgb -.->|read only| r2[(Replica 2)]
    primary == streaming WAL ==> r1
    primary == streaming WAL ==> r2
    primary -->|archive_command| s3[/S3 WAL archive/]
```

## Decision flow: which backup tool?

```mermaid
flowchart TD
    start([Need a backup]) --> size{Database size?}
    size -->|< 100 GB| logical{Need single-table restore?}
    size -->|>= 100 GB| pitr{Need point-in-time recovery?}
    logical -->|Yes| dump[pg_dump -Fc]
    logical -->|No| basebackup[pg_basebackup]
    pitr -->|Yes| barman[Barman / pgBackRest + WAL archive]
    pitr -->|No| snap[Storage snapshots]
    dump --> test[[Test the restore!]]
    basebackup --> test
    barman --> test
    snap --> test
```

## Mermaid 11 shape syntax

Mermaid 11.3+ adds 30+ new shapes using `id@{ shape: …, label: "…" }`.

```mermaid
flowchart LR
    client@{ shape: rounded, label: "Client" }
    parse@{ shape: rect, label: "Parser" }
    plan@{ shape: diam, label: "Planner" }
    exec@{ shape: subproc, label: "Executor" }
    heap@{ shape: cyl, label: "Heap" }
    wal@{ shape: lin-cyl, label: "WAL" }
    log@{ shape: doc, label: "Server log" }
    stats@{ shape: docs, label: "pg_stat_*" }

    client --> parse --> plan --> exec
    exec --> heap
    exec --> wal
    exec -.-> log
    exec -.-> stats
```

## Subgraphs and styling

```mermaid
flowchart TB
    subgraph az1 [Availability Zone A]
        p[(Primary)]
        b1[PgBouncer]
    end
    subgraph az2 [Availability Zone B]
        s[(Sync standby)]
        b2[PgBouncer]
    end
    subgraph az3 [Availability Zone C]
        a[(Async replica)]
    end

    b1 --> p
    b2 --> p
    p -- synchronous_commit = on --> s
    p -. async .-> a

    classDef primary fill:#2563eb,stroke:#1e40af,color:#fff
    classDef standby fill:#0891b2,stroke:#155e75,color:#fff
    class p primary
    class s,a standby
```

## Animated edges (11.5+)

```mermaid
flowchart LR
    primary[(Primary)] e1@==> replica[(Replica)]
    e1@{ animate: true }
```
