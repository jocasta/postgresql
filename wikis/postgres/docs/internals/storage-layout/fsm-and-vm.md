# Free Space Map and Visibility Map

## Free Space Map (FSM)

- One byte per heap page recording approximate free space (in 1/256ths of a page), stored as a tree so the insert path can find a page with enough room quickly.
- Updated mainly by VACUUM — after deletes, space isn't advertised until vacuum runs.
- Index FSMs track wholly empty pages that can be recycled.

```sql
CREATE EXTENSION IF NOT EXISTS pg_freespacemap;
SELECT * FROM pg_freespace('orders') WHERE avail > 0 LIMIT 10;
```

## Visibility Map (VM)

Two bits per heap page:

| Bit | Meaning | Used by |
|---|---|---|
| **all-visible** | Every tuple is visible to all transactions | **Index-only scans** skip the heap fetch; VACUUM skips the page |
| **all-frozen** | Every tuple is frozen | Aggressive (anti-wraparound) VACUUM skips the page |

Any change to a page clears its bits; VACUUM sets them again.

```sql
CREATE EXTENSION IF NOT EXISTS pg_visibility;
SELECT * FROM pg_visibility_map_summary('orders');   -- all_visible, all_frozen page counts

-- Fraction of the table index-only scans can use without heap fetches
SELECT relname, relpages, relallvisible,
       round(100.0 * relallvisible / nullif(relpages, 0), 1) AS pct_all_visible
FROM pg_class WHERE relname = 'orders';
```

If `EXPLAIN ANALYZE` shows `Index Only Scan … Heap Fetches: 50000`, the VM is stale — vacuum the table.
