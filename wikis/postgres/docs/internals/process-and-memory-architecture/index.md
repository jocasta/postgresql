# Process and Memory Architecture

```mermaid
flowchart TB
    pm[postmaster]
    subgraph clients [Per-connection]
        b1[backend]
        b2[backend]
        pw[parallel workers]
    end
    subgraph aux [Auxiliary / background processes]
        ckpt[checkpointer]
        bgw[background writer]
        walw[WAL writer]
        avl[autovacuum launcher] --> avw[autovacuum workers]
        arch[archiver]
        ws[WAL sender]
        lrl[logical replication launcher] --> lra[apply / tablesync workers]
        iow[io workers PG18]
    end
    shm[(Shared memory: shared_buffers, WAL buffers, lock table, proc array, SLRU caches)]
    pm --> b1 & b2
    b1 --> pw
    pm --> aux
    b1 & b2 & pw <--> shm
    aux <--> shm
```

## Pages

| Page |
|---|
| [Postmaster, backends and process-per-connection](postmaster-and-backends.md) |
| [Auxiliary processes](auxiliary-processes.md) |
| [Shared memory](shared-memory.md) |
| [Local (per-backend) memory](local-memory.md) |
| [Dynamic shared memory and parallel query](dynamic-shared-memory-and-parallel-query.md) |
