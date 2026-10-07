# Transaction IDs, wraparound and freezing

- Each writing transaction gets a 32-bit **XID**. Read-only transactions only get a *virtual* xid (`vxid`) — a real XID is assigned lazily at the first write.
- XIDs are compared **modulo 2³²**: for any XID, ~2.1 billion XIDs are "in the past" and ~2.1 billion "in the future". If a tuple's `xmin` gets more than 2³¹ transactions old without being frozen, it would suddenly appear to be in the future — i.e. invisible. That's **transaction ID wraparound**.
- **Freezing** marks a tuple's `xmin` as "committed and older than every XID" (the `HEAP_XMIN_FROZEN` infomask bits), so its age no longer matters. VACUUM freezes tuples older than `vacuum_freeze_min_age`.
- Each table tracks `pg_class.relfrozenxid` (all XIDs older than this are frozen); each database tracks `pg_database.datfrozenxid` (minimum across its tables).
- Special XIDs: `0` invalid, `1` bootstrap, `2` frozen; normal XIDs start at 3.
- 64-bit "full" XIDs (`xid8`, epoch + xid) are exposed via `pg_current_xact_id()`, but tuples still store 32 bits.

```sql
SELECT pg_current_xact_id();      -- assigns an XID if none yet (xid8)
SELECT pg_current_xact_id_if_assigned();

-- Distance to wraparound per database
SELECT datname, age(datfrozenxid) AS xid_age,
       round(100.0 * age(datfrozenxid) / 2147483647, 2) AS pct_to_wraparound
FROM pg_database ORDER BY 2 DESC;
```

Safety limits as age approaches 2³¹: warnings at ~40M remaining, and at ~3M remaining the server refuses to assign new XIDs until the database is vacuumed.

See also: [Transaction Wraparound](../../monitoring/transaction-wraparound/0-transaction-wraparound.md), [Fixing Transaction Wraparound](../../monitoring/transaction-wraparound/1-fixing-transaction-wraparound.md), [Aggressive vacuum and freezing](../vacuum-and-bloat-management/aggressive-vacuum-and-freezing.md).
