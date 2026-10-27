# Managed-service specifics (AWS)

!!! note
    AWS behaviour changes between engine versions. Check the RDS / Aurora PostgreSQL user guides for your exact version before relying on details here.

## RDS / Aurora PostgreSQL parameters (rds.logical_replication)

You can't set `wal_level` directly on RDS or Aurora. Instead:

| Parameter | Where | Value | Effect |
|---|---|---|---|
| `rds.logical_replication` | DB parameter group (RDS) / **DB cluster** parameter group (Aurora) | `1` | Sets `wal_level = logical`. **Static: reboot required** |
| `max_replication_slots` | same | e.g. `20` | Slots for subscriptions / CDC |
| `max_wal_senders` | same | e.g. `20` | Walsenders |
| `max_logical_replication_workers` | subscriber's group | e.g. `10` | Apply/sync workers |
| `max_worker_processes` | subscriber's group | ≥ workers + others | Background workers |
| `max_slot_wal_keep_size` | same | e.g. `100000` (MB) | Cap retained WAL |
| `logical_decoding_work_mem` | same | `64MB`–`1GB` | Reduce spill |

```sql
SHOW rds.logical_replication;   -- on
SHOW wal_level;                 -- logical
```

```bash
aws rds modify-db-parameter-group \
  --db-parameter-group-name my-pg17-params \
  --parameters "ParameterName=rds.logical_replication,ParameterValue=1,ApplyMethod=pending-reboot"
aws rds reboot-db-instance --db-instance-identifier my-db
```

Turning on `rds.logical_replication` slightly increases WAL volume and storage I/O even when no slots exist.

## Required roles (rds_replication)

There's no real superuser on RDS/Aurora. The master user has `rds_superuser`.

| Task | Requirement |
|---|---|
| Create a publication `FOR TABLE` | Table owner |
| Create a publication `FOR ALL TABLES` / `TABLES IN SCHEMA` | `rds_superuser` |
| Create / use a logical replication slot | `rds_replication` (or `rds_superuser`, which includes it) |
| Create a subscription (subscriber on RDS) | `rds_superuser` (PG 16+: or `pg_create_subscription` + `CREATE` on the database) |
| Replication connection user | Needs `rds_replication` (instead of the `REPLICATION` attribute) and `SELECT` on published tables |

```sql
CREATE ROLE repl WITH LOGIN PASSWORD '...';
GRANT rds_replication TO repl;
GRANT USAGE ON SCHEMA app TO repl;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO repl;
```

Security groups / NACLs must allow the subscriber to reach the publisher on 5432. There is no `pg_hba.conf` to edit on RDS (it's managed; SSL can be forced with `rds.force_ssl = 1`).

## Aurora-specific behaviour and limitations

- **Publish from the writer**: logical slots live on the **writer** instance. Aurora readers don't host logical slots.
- **Failover**: Aurora shares storage between writer and readers, so after an in-cluster failover the logical slots are still there on the new writer. This differs from community PostgreSQL before PG 17. Subscribers reconnect via the **cluster endpoint**. Always use the cluster (writer) endpoint in `CONNECTION`, not an instance endpoint.
- **WAL storage**: Aurora doesn't have a local `pg_wal` like RDS, but WAL retained for slots still consumes storage and is billed. Monitor slot lag.
- **`aurora.enhanced_logical_replication`** (newer Aurora PG versions): a cluster parameter that improves logical decoding performance by caching WAL changes. Check AWS docs for supported versions and its trade-offs before enabling.
- **Aurora Global Database**: logical replication from a global database's primary cluster is supported, with extra considerations around global failover. Check AWS docs for your version.
- **Blue/Green Deployments**: RDS/Aurora Blue/Green for major version upgrades **uses logical replication internally**. It has its own restrictions (e.g. DDL during the green phase, tables without PKs, existing logical replication setups). Read the current AWS limitations list.

**CloudWatch metrics** worth alarming on:

| Metric | Engine | Meaning |
|---|---|---|
| `OldestReplicationSlotLag` | RDS / Aurora | WAL (bytes) held by the most-lagging slot |
| `TransactionLogsDiskUsage` | RDS | Disk used by WAL |
| `ReplicationSlotDiskUsage` | RDS | Disk used by replication slot files |
| `FreeStorageSpace` | RDS | Free disk |
| `TransactionLogsGeneration` | RDS | WAL generation rate |

## Using DMS vs native logical replication

| | Native logical replication | AWS DMS |
|---|---|---|
| Source / target engines | PostgreSQL → PostgreSQL | Many (Oracle, MySQL, SQL Server, S3, Redshift, Kinesis, …) |
| Underlying mechanism | `pgoutput` + subscriptions | Logical decoding (`test_decoding` or `pglogical`) via its own slot |
| Infrastructure | None (just the two databases) | Replication instance (cost, sizing) |
| Initial load | `COPY` per table | Full load tasks, parallel options |
| Data types | Full PostgreSQL type fidelity | Some type mapping limitations (LOBs, arrays, JSON, PostGIS need care) |
| Transformations | Row filters / column lists only | Table/column mapping, transformation rules |
| DDL | Not replicated | Limited DDL capture for some sources |
| Sequences | Not replicated (pre-PG 19) | Not replicated |
| Monitoring | SQL views | DMS console, CloudWatch, validation tasks |
| Data validation | Manual | Built-in validation option |
| Best for | PG → PG upgrades/migrations | Heterogeneous migrations, streaming to non-PG targets |

Rule of thumb: **PostgreSQL to PostgreSQL → native logical replication.** Use DMS when the target (or source) is not PostgreSQL, or you need transformations or built-in validation.
