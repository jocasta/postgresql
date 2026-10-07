# Aggressive vacuum, freeze ages and relfrozenxid

| Setting | Default | Effect |
|---|---|---|
| `vacuum_freeze_min_age` | 50M | Tuples older than this get frozen when vacuum visits their page |
| `vacuum_freeze_table_age` | 150M | If `age(relfrozenxid)` exceeds this, VACUUM is **aggressive**: scans every page not marked all-frozen |
| `autovacuum_freeze_max_age` | 200M | Forces an **anti-wraparound autovacuum** even if autovacuum is off for the table |
| `vacuum_failsafe_age` | 1.6B | PG14+: vacuum drops cost delay and skips index vacuuming to finish freezing ASAP |
| `autovacuum_multixact_freeze_max_age` | 400M | Same for multixacts |

- A **normal** vacuum skips all-visible pages, so it can't advance `relfrozenxid` past tuples on those pages.
- An **aggressive** vacuum visits all non-all-frozen pages and can advance `relfrozenxid`.
- **Anti-wraparound autovacuums** (`autovacuum: VACUUM … (to prevent wraparound)` in `pg_stat_activity`) are **not cancelled** by conflicting lock requests — an `ALTER TABLE` will queue behind them.
- PG16+ also freezes pages opportunistically when a full-page image is being written anyway.

```sql
SELECT c.oid::regclass AS table,
       age(c.relfrozenxid) AS xid_age,
       mxid_age(c.relminmxid) AS mxid_age,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS size
FROM pg_class c
WHERE c.relkind IN ('r', 'm', 't')
ORDER BY age(c.relfrozenxid) DESC
LIMIT 20;
```

Tip: for append-only/insert-heavy tables, the PG13+ insert-triggered autovacuum keeps freezing incremental; `VACUUM (FREEZE)` after bulk loads avoids a huge anti-wraparound vacuum later.
