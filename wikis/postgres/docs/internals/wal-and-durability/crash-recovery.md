# Crash recovery and redo

```mermaid
sequenceDiagram
    participant PM as Postmaster
    participant SU as Startup process
    participant C as pg_control
    participant W as pg_wal
    participant D as Data pages
    PM->>SU: cluster was not shut down cleanly
    SU->>C: read latest checkpoint and REDO point
    loop for each WAL record from REDO point
        SU->>W: read record
        alt record has full-page image
            SU->>D: restore page from image
        else page LSN older than record LSN
            SU->>D: apply change
        else page LSN already newer
            SU->>SU: skip, change already on disk
        end
    end
    SU->>D: end-of-recovery checkpoint
    SU->>PM: ready to accept connections
```

- Replay is **idempotent** thanks to the page LSN comparison.
- Uncommitted transactions need no undo: their changes are replayed but their XIDs have no commit record, so they're aborted in clog and invisible.
- Recovery time ≈ WAL generated since the last checkpoint — bounded by `checkpoint_timeout` / `max_wal_size`.
- The same machinery drives **streaming replication** and **PITR**: a standby is a server in permanent recovery.
