# Shared memory

Allocated once at startup by the postmaster (size fixed until restart).

| Area | Sized by | Purpose |
|---|---|---|
| Shared buffer pool | `shared_buffers` (default 128 MB, typically ~25% RAM) | Cached data / index pages — see [Buffer Manager](../buffer-manager-and-io/index.md) |
| WAL buffers | `wal_buffers` (default -1 = 1/32 of `shared_buffers`, max one WAL segment) | WAL records waiting to be written |
| Lock table | `max_locks_per_transaction` × (`max_connections` + `max_prepared_transactions`) | Heavyweight locks (`pg_locks`) |
| Predicate lock table | `max_pred_locks_per_transaction` | SSI SIREAD locks |
| Proc array / PGPROC | `max_connections` + workers | One entry per process: xid, xmin, subxid cache — used to build snapshots |
| SLRU caches | PG17+: `transaction_buffers`, `subtransaction_buffers`, `multixact_*_buffers`, … | Cached pages of `pg_xact`, `pg_subtrans`, `pg_multixact`, `pg_commit_ts`, `pg_serial`, `pg_notify` |

**SLRU** ("simple least-recently-used") caches hold small fixed-size pages of on-disk transaction metadata:

- **pg_xact (clog)** — commit status, 2 bits per transaction.
- **pg_subtrans** — parent xid for each subtransaction.
- **pg_multixact** — `offsets` and `members` for multixacts.

Contention on these shows up as `LWLock` waits like `XactSLRU`, `SubtransSLRU`, `MultiXactOffsetSLRU`.

```sql
-- What is shared memory used for? (PG13+)
SELECT name, pg_size_pretty(allocated_size) AS size
FROM pg_shmem_allocations
ORDER BY allocated_size DESC
LIMIT 15;

SHOW shared_memory_size;                -- PG15+: total, computed at startup
SHOW shared_memory_size_in_huge_pages;  -- for sizing vm.nr_hugepages

-- SLRU hit/miss stats
SELECT name, blks_hit, blks_read, blks_zeroed, flushes
FROM pg_stat_slru;
```

!!! tip
    Use `huge_pages = on` (with `vm.nr_hugepages` set) for large `shared_buffers` — it cuts page-table overhead in every backend.
