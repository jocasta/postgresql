# Hint bits and the commit log

The **commit log** (`pg_xact`, formerly `pg_clog`) stores 2 bits per XID:

| Status | Bits |
|---|---|
| In progress | `00` |
| Committed | `01` |
| Aborted | `10` |
| Sub-committed | `11` |

One 8 KB page covers 32,768 XIDs. Looking up status in clog for every tuple would be slow, so the first backend that checks a tuple whose inserter/deleter has finished sets **hint bits** in the tuple header:

- `HEAP_XMIN_COMMITTED` / `HEAP_XMIN_INVALID`
- `HEAP_XMAX_COMMITTED` / `HEAP_XMAX_INVALID`

Consequences:

- **The first read after a bulk load writes**: a `SELECT` sets hint bits, dirtying every page — those pages are then written out again. Run `VACUUM` (or `VACUUM FREEZE`) after a large load to do this once, up front.
- Setting a hint bit is not WAL-logged by default, **unless** data checksums or `wal_log_hints = on` are enabled — then the first hint-bit change after a checkpoint emits a full-page image.
- Hint bits are only set once the XID is older than the snapshot horizon and the commit record is flushed.
