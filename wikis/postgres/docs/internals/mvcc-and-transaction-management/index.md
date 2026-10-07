# MVCC and Transaction Management

PostgreSQL implements **Multi-Version Concurrency Control** by keeping multiple versions of each row in the heap. Readers never block writers and writers never block readers: each transaction sees the versions that were committed as of its **snapshot**.

## Pages

| Page |
|---|
| [Transaction IDs, wraparound and freezing](xids-wraparound-and-freezing.md) |
| [Snapshots and visibility rules](snapshots-and-visibility.md) |
| [Hint bits and the commit log](hint-bits-and-clog.md) |
| [Isolation levels and SSI](isolation-levels-and-ssi.md) |
| [Subtransactions, savepoints and subxid overflow](subtransactions.md) |
| [Multixacts](multixacts.md) |
| [Two-phase commit and prepared transactions](two-phase-commit.md) |
