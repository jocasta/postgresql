# Two-phase commit and prepared transactions

Two-phase commit (2PC) lets an external transaction manager coordinate a commit across multiple databases:

```sql
-- needs max_prepared_transactions > 0 (default 0, restart required)
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
PREPARE TRANSACTION 'transfer-42';   -- phase 1: durable, survives restart, session detaches

-- later, from any session:
COMMIT PREPARED 'transfer-42';       -- phase 2
-- or ROLLBACK PREPARED 'transfer-42';
```

```sql
SELECT gid, prepared, owner, database, age(transaction) AS xid_age
FROM pg_prepared_xacts
ORDER BY prepared;
```

!!! danger "Orphaned prepared transactions"
    A prepared transaction keeps its **locks** and its **XID** forever until resolved — it holds back the xmin horizon (bloat) and blocks freezing (wraparound). They survive restarts and don't appear as sessions in `pg_stat_activity`.
    Keep `max_prepared_transactions = 0` unless you actually use 2PC, and alert on rows in `pg_prepared_xacts` older than a few minutes.
