# References

## Official documentation chapters

PostgreSQL documentation (current version; change `current` in the URL to e.g. `16` for a specific version):

| Topic | Link |
|---|---|
| Logical Replication (chapter) | <https://www.postgresql.org/docs/current/logical-replication.html> |
| Publication | <https://www.postgresql.org/docs/current/logical-replication-publication.html> |
| Subscription | <https://www.postgresql.org/docs/current/logical-replication-subscription.html> |
| Row filters | <https://www.postgresql.org/docs/current/logical-replication-row-filter.html> |
| Column lists | <https://www.postgresql.org/docs/current/logical-replication-col-lists.html> |
| Conflicts | <https://www.postgresql.org/docs/current/logical-replication-conflicts.html> |
| Restrictions | <https://www.postgresql.org/docs/current/logical-replication-restrictions.html> |
| Architecture | <https://www.postgresql.org/docs/current/logical-replication-architecture.html> |
| Monitoring | <https://www.postgresql.org/docs/current/logical-replication-monitoring.html> |
| Security | <https://www.postgresql.org/docs/current/logical-replication-security.html> |
| Configuration settings | <https://www.postgresql.org/docs/current/logical-replication-config.html> |
| Logical Decoding (chapter) | <https://www.postgresql.org/docs/current/logicaldecoding.html> |
| Replication protocol | <https://www.postgresql.org/docs/current/protocol-replication.html> |
| `CREATE PUBLICATION` | <https://www.postgresql.org/docs/current/sql-createpublication.html> |
| `CREATE SUBSCRIPTION` | <https://www.postgresql.org/docs/current/sql-createsubscription.html> |
| `ALTER SUBSCRIPTION` | <https://www.postgresql.org/docs/current/sql-altersubscription.html> |
| `ALTER TABLE ... REPLICA IDENTITY` | <https://www.postgresql.org/docs/current/sql-altertable.html#SQL-ALTERTABLE-REPLICA-IDENTITY> |
| Replication configuration parameters | <https://www.postgresql.org/docs/current/runtime-config-replication.html> |
| `pg_replication_slots` | <https://www.postgresql.org/docs/current/view-pg-replication-slots.html> |
| Monitoring stats views | <https://www.postgresql.org/docs/current/monitoring-stats.html> |
| `pg_createsubscriber` | <https://www.postgresql.org/docs/current/app-pgcreatesubscriber.html> |
| `pg_upgrade` | <https://www.postgresql.org/docs/current/pgupgrade.html> |

AWS:

| Topic | Link |
|---|---|
| RDS PostgreSQL logical replication | <https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.FeatureSupport.LogicalReplication.html> |
| Aurora PostgreSQL logical replication | <https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraPostgreSQL.Replication.Logical.html> |
| AWS DMS: PostgreSQL as a source | <https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Source.PostgreSQL.html> |

!!! note
    AWS documentation URLs change occasionally; search the page title if a link is broken.

## Release note links

| Version | Release notes |
|---|---|
| All versions | <https://www.postgresql.org/docs/release/> |
| PostgreSQL 10 | <https://www.postgresql.org/docs/10/release-10.html> |
| PostgreSQL 13 | <https://www.postgresql.org/docs/13/release-13.html> |
| PostgreSQL 14 | <https://www.postgresql.org/docs/14/release-14.html> |
| PostgreSQL 15 | <https://www.postgresql.org/docs/15/release-15.html> |
| PostgreSQL 16 | <https://www.postgresql.org/docs/16/release-16.html> |
| PostgreSQL 17 | <https://www.postgresql.org/docs/17/release-17.html> |
| PostgreSQL 18 | <https://www.postgresql.org/docs/18/release-18.html> |

Search each for "logical replication" and "logical decoding". See [Version history](version-history.md) for a summary.

## Mailing list threads and talks

- **pgsql-hackers archive**: design discussions for every logical replication feature. Search by feature name (e.g. "failover slots", "parallel apply", "conflict detection"): <https://www.postgresql.org/list/pgsql-hackers/>
- **Commitfest**: in-progress patches for future versions: <https://commitfest.postgresql.org/>
- **PostgreSQL Wiki – Logical replication / decoding pages**: <https://wiki.postgresql.org/>
- **PGConf / PGCon / PGConf.EU talk archives**: many talks on logical replication internals, upgrades and CDC. Search the conference sites and their YouTube channels.
- **Debezium PostgreSQL connector docs**: <https://debezium.io/documentation/reference/stable/connectors/postgresql.html>
- **pglogical**: <https://github.com/2ndQuadrant/pglogical>

Related pages in this wiki:

- [Quick Start](../setup-guides/quick-start.md)
- [Sample Major Version Upgrade](../setup-guides/sample-major-version-upgrade.md)
- [Logical Replication SQL](../sql/logical-replication-queries.md)
- [Blogs](../blogs/index.md)
