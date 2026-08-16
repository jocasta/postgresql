# WAL Files

## Replication Slots Holding WAL

Replication slots prevent WAL segment removal until all consumers have caught up.
Monitor for slots that are falling behind — they can fill your disk.

```sql
--8<-- "wal/Replication_Slots_Holding_WALS.sql"
```
