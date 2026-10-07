# Buffer Manager and I/O

Every read or write of a table or index page goes through the **shared buffer pool**. Backends never read data files directly into private memory (except temp tables via local buffers).

## Pages

| Page |
|---|
| [Buffer pool, descriptors and the mapping hash](buffer-pool-structure.md) |
| [Clock-sweep eviction and usage counts](clock-sweep-eviction.md) |
| [Ring buffers](ring-buffers.md) |
| [Background writer vs checkpointer vs backend writes](background-writer-vs-checkpointer.md) |
| [OS page cache and double buffering](os-page-cache.md) |
| [Direct I/O and async I/O (PG17 / PG18)](direct-and-async-io.md) |
| [pg_buffercache and pg_stat_io](pg-buffercache-and-pg-stat-io.md) |
