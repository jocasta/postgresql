# WAL records, LSNs and segment files

## Records

Each WAL record has:

- **Header** (`XLogRecord`) — total length, XID, pointer to the previous record (`xl_prev`), resource manager id (`xl_rmid`), info flags, CRC.
- **Block references** — which relation/fork/block it touches, optionally with a full-page image.
- **Main data** — the resource-manager-specific payload (e.g. "insert tuple at offset 5").

Resource managers: `Heap`, `Heap2`, `Btree`, `Transaction`, `XLOG`, `Standby`, `Gin`, `Gist`, `Sequence`, …

## LSNs

A **Log Sequence Number** is a 64-bit byte position in the WAL stream, shown as two hex halves: `0/1A2B3C40`. Every data page stores the LSN of the last record that modified it (`pd_lsn`).

```sql
SELECT pg_current_wal_lsn();                         -- current write position
SELECT pg_current_wal_insert_lsn();
SELECT pg_walfile_name(pg_current_wal_lsn());        -- which segment file
SELECT pg_size_pretty(pg_wal_lsn_diff('0/5000000', '0/3000000'));  -- bytes between LSNs
```

## Segment files

WAL is stored in `pg_wal/` as **16 MB segments** (set at `initdb --wal-segsize`), each made of 8 KB WAL pages. File names are 24 hex digits:

```
00000001 00000003 0000004A
└timeline┘└─ log ─┘└─ seg ─┘
```

Old segments are recycled (renamed) or removed after checkpoints, unless retained by `wal_keep_size`, replication slots or failed archiving.

```bash
pg_waldump --stats=record -p $PGDATA/pg_wal 000000010000000300000040
pg_waldump -p $PGDATA/pg_wal -s 3/40000000 -n 20     # first 20 records from an LSN
```

```sql
SELECT * FROM pg_stat_wal;     -- wal_records, wal_fpi, wal_bytes, wal_buffers_full
```
