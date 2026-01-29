

### Summary Table: Append-Heavy Tuning

| Parameter | Recommended Value | Impact |
| --- | --- | --- |
| **`synchronous_commit`** | `off` | Massive throughput increase; small data loss risk. |
| **`wal_buffers`** | `64MB` to `128MB` | Prevents "bottlenecking" during WAL writes. |
| **`max_wal_size`** | `32GB`+ | Reduces frequency of expensive checkpoints. |
| **Index Type** | **BRIN** | Dramatically reduces index size and write overhead. |
| **Storage** | **Partitioning** | Keeps indexes small and enables instant data deletion. |


---

### Summary Table: Tuning for Heavy Reads (Analytics & Reporting)

The goal here is to keep data in memory and enable the CPU to crunch large datasets in parallel.

| Parameter | Recommended Value | Why it helps |
| --- | --- | --- |
| **`shared_buffers`** | **25% - 40% of RAM** | Increases the "cache" so Postgres finds data in RAM instead of hitting the disk. |
| **`effective_cache_size`** | **75% of total RAM** | Helps the query planner realize there is a lot of OS-level cache available, favoring index scans. |
| **`work_mem`** | **64MB - 256MB+** | Memory for sorting and joins. High values prevent queries from "spilling" to slow disk-based temp files. |
| **`max_parallel_workers_per_gather`** | **4 to 8** | Allows a single query to use multiple CPU cores to scan large tables or aggregate data. |
| **`random_page_cost`** | **1.1** | (For SSDs) Tells the engine that random disk access is fast, making it use indexes more aggressively. |
| **`cursor_tuple_fraction`** | **1.0** | Tells the planner you likely want *all* rows of a query (typical for reports) rather than just the first few. |

---

### Summary Table: Tuning for Heavy Writes (Ingestion & Data Loading)

The goal here is to reduce the "friction" of saving data to disk and minimize the impact of maintenance tasks.

| Parameter | Recommended Value | Why it helps |
| --- | --- | --- |
| **`synchronous_commit`** | **`off`** | **The biggest boost.** The DB doesn't wait for a slow disk "confirm" before moving to the next write. |
| **`max_wal_size`** | **16GB - 64GB** | Allows more data to be written before a "checkpoint" is forced, reducing massive I/O spikes. |
| **`checkpoint_timeout`** | **15min - 30min** | Spreads out the work of flushing data to disk over a longer period. |
| **`checkpoint_completion_target`** | **0.9** | Spreads the checkpoint write load across 90% of the timeout interval to stay "smooth." |
| **`wal_buffers`** | **16MB - 64MB** | Provides a larger buffer for incoming write logs before they must be flushed to the WAL files. |
| **`autovacuum_vacuum_scale_factor`** | **0.01 - 0.05** | Triggers cleanup after 1% or 5% of data changes (instead of 20%), preventing massive "bloat." |
| **`maintenance_work_mem`** | **1GB - 2GB** | Speeds up the internal processes that clean the database and rebuild indexes after large loads. |

---
