# Subtransactions, savepoints and subxid overflow

**Subtransactions** are created by:

- `SAVEPOINT` / `ROLLBACK TO SAVEPOINT`
- PL/pgSQL blocks with an `EXCEPTION` clause (every entry into the block!)
- Some drivers/ORMs that wrap each statement in a savepoint (e.g. JDBC `autosave=always`, Django atomic nesting)

Each subtransaction that writes gets its own XID, and its parent is recorded in **`pg_subtrans`**.

## The overflow problem

- Each backend's PGPROC caches up to **64** subtransaction XIDs (`PGPROC_MAX_CACHED_SUBXIDS`).
- With more than 64 in one transaction, the cache **overflows**. Every snapshot taken by *any* backend while that transaction runs is marked overflowed, and visibility checks must look up parent XIDs in `pg_subtrans` (an SLRU).
- Under load this causes heavy `SubtransSLRU` / `SubtransBuffer` LWLock contention — and it is especially bad on **hot standbys**, where a single long transaction with overflowed subxids on the primary can slow every query on the replica.

```sql
-- PG16+: subtransaction count per backend
SELECT a.pid, s.subxact_count, s.subxact_overflowed, left(a.query, 60)
FROM pg_stat_activity a
CROSS JOIN LATERAL pg_stat_get_backend_subxact(a.pid) s
WHERE s.subxact_count > 0;

-- Look for these waits
SELECT wait_event_type, wait_event, count(*)
FROM pg_stat_activity
WHERE wait_event ILIKE '%subtrans%'
GROUP BY 1, 2;
```

Avoid: savepoints per row in loops, `EXCEPTION` blocks inside loops, long transactions with many savepoints. PG17 makes `subtransaction_buffers` tunable.
