# Multixacts

`t_xmax` has room for one XID. When **several transactions lock the same row at once** (shared locks), PostgreSQL stores a **MultiXactId** in `t_xmax` instead (with `HEAP_XMAX_IS_MULTI` set), pointing into:

- `pg_multixact/offsets` — MultiXactId → position in members
- `pg_multixact/members` — the member XIDs and their lock modes

Common sources:

- **Foreign key checks** — inserting a child row takes `FOR KEY SHARE` on the parent row. Many concurrent inserts referencing the same parent ⇒ multixacts.
- Explicit `SELECT … FOR SHARE` / `FOR KEY SHARE`.
- A lock plus an update on the same row by different transactions.

Multixacts have their own 32-bit counter and their own **wraparound** problem, plus the members space can be exhausted:

```sql
SELECT datname, mxid_age(datminmxid) AS multixact_age FROM pg_database;

SELECT relname, mxid_age(relminmxid) AS multixact_age
FROM pg_class WHERE relkind IN ('r', 'm', 't')
ORDER BY 2 DESC LIMIT 10;
```

Tuned by `autovacuum_multixact_freeze_max_age` (400M), `vacuum_multixact_freeze_min_age`, `vacuum_multixact_freeze_table_age`. Contention shows as `MultiXactOffsetSLRU` / `MultiXactMemberSLRU` waits.
