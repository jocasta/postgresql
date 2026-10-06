# Planning & Process

## Gantt — major version upgrade plan

```mermaid
gantt
    title PostgreSQL 16 → 18 upgrade
    dateFormat YYYY-MM-DD
    axisFormat %d %b
    excludes weekends

    section Prep
    Extension compatibility check   :done,   prep1, 2026-10-01, 3d
    Build PG18 staging cluster      :active, prep2, after prep1, 4d
    section Testing
    pg_upgrade dry run on staging   :test1, after prep2, 2d
    App regression tests            :test2, after test1, 5d
    Performance benchmark (pgbench) :test3, after test1, 3d
    section Cutover
    Logical replication to new primary :cut1, after test2, 3d
    Switchover window                  :crit, milestone, cut2, after cut1, 0d
    section Cleanup
    Decommission old cluster        :after cut2, 5d
```

## Timeline — recent PostgreSQL releases

```mermaid
timeline
    title PostgreSQL major releases
    2020 : PG13 : Incremental sort : B-tree deduplication
    2021 : PG14 : Pipeline mode : pg_stat_wal
    2022 : PG15 : MERGE : Logical replication row filters
    2023 : PG16 : pg_stat_io : Logical decoding on standbys
    2024 : PG17 : Incremental backup : pg_createsubscriber
    2025 : PG18 : Async I/O : uuidv7()
```

## User journey — on-call slow query incident

```mermaid
journey
    title Slow query incident
    section Detect
      Alert fires on p99 latency: 2: On-call
      Check dashboards: 3: On-call
    section Diagnose
      Query pg_stat_activity: 4: On-call
      Find plan via auto_explain: 4: On-call, DBA
    section Fix
      Add missing index CONCURRENTLY: 5: DBA
      Verify latency recovered: 5: On-call
```

## Kanban (11.4+)

```mermaid
kanban
    todo[To Do]
        t1[Enable pg_stat_statements on reporting DB]
        t2[Review autovacuum settings]@{ priority: 'High' }
    doing[In Progress]
        t3[Partition events table with pg_partman]@{ assigned: 'mike', priority: 'Very High' }
    review[Review]
        t4[UUIDv7 migration script]
    done[Done]
        t5[Upgrade PgBouncer]
```

## Git graph — schema migration branches

```mermaid
gitGraph
    commit id: "V1__init"
    commit id: "V2__orders"
    branch feature/partitioning
    checkout feature/partitioning
    commit id: "V3__events_partitioned"
    commit id: "V4__partman_config"
    checkout main
    branch hotfix/index
    commit id: "V3_1__orders_idx"
    checkout main
    merge hotfix/index
    merge feature/partitioning
    commit id: "V5__drop_old_events" type: HIGHLIGHT
```
