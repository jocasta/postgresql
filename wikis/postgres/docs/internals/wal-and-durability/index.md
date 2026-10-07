# Write-Ahead Logging and Durability

**The WAL rule:** a change to a data page may only be written to disk *after* the WAL record describing it has been flushed. On commit, only the WAL needs to reach disk — data pages can be written later, because WAL can always redo them.

## Pages

| Page |
|---|
| [WAL records, LSNs and segment files](wal-records-lsns-segments.md) |
| [Full-page writes and torn pages](full-page-writes.md) |
| [Checkpoints](checkpoints.md) |
| [Crash recovery and redo](crash-recovery.md) |
| [synchronous_commit and group commit](synchronous-commit-and-group-commit.md) |
| [WAL archiving and PITR](archiving-and-pitr.md) |
| [WAL compression and wal_level](wal-compression-and-wal-level.md) |
