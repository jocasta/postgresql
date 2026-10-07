# Bloat causes

VACUUM can only remove tuples older than the **xmin horizon**. Anything that holds the horizon back stops cleanup **across the whole cluster**:

| Cause | How to find it | Fix |
|---|---|---|
| Long-running / idle-in-transaction sessions | `pg_stat_activity.backend_xmin`, `xact_start`, `state = 'idle in transaction'` | `idle_in_transaction_session_timeout`, `transaction_timeout` (PG17), fix the app |
| Replication slots (inactive or lagging) | `pg_replication_slots.xmin` / `catalog_xmin` | Drop unused slots, `max_slot_wal_keep_size` |
| `hot_standby_feedback = on` with long queries on a replica | `pg_stat_replication.backend_xmin` | Limit replica query duration, or accept conflicts |
| Orphaned prepared transactions | `pg_prepared_xacts` | `ROLLBACK PREPARED` |
| Autovacuum too slow / too late | `n_dead_tup`, `last_autovacuum` | Lower scale factors, raise cost limit |
| Update-heavy rows with no HOT | `n_tup_hot_upd` | `fillfactor`, fewer indexes |

```sql
-- What is holding back the xmin horizon?
SELECT 'backend' AS source, pid::text AS id, age(backend_xmin) AS xmin_age, state, xact_start::text AS since
FROM pg_stat_activity WHERE backend_xmin IS NOT NULL
UNION ALL
SELECT 'replication slot', slot_name, greatest(age(xmin), age(catalog_xmin)), active::text, NULL
FROM pg_replication_slots WHERE xmin IS NOT NULL OR catalog_xmin IS NOT NULL
UNION ALL
SELECT 'standby feedback', application_name, age(backend_xmin), state, NULL
FROM pg_stat_replication WHERE backend_xmin IS NOT NULL
UNION ALL
SELECT 'prepared xact', gid, age(transaction), NULL, prepared::text
FROM pg_prepared_xacts
ORDER BY xmin_age DESC NULLS LAST;
```

`VACUUM (VERBOSE)` reports it directly: `tuples: 0 removed, … 120000 are dead but not yet removable, oldest xmin: 7341`.

Measuring bloat: see [pgstattuple](../../extensions/pgstattuple/index.md) and [Admin Queries → Bloat](../../admin-queries/bloat.md).
