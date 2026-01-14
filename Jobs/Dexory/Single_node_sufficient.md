
Not “surely”, no. That number on its own doesn’t force you off a single Postgres node.

**1,000,000 data points/day/warehouse** is only scary once you pin down:

* how many warehouses,
* how big each “data point” is on disk,
* how long you retain it in Postgres,
* how much analytics you run *on the primary*,
* how many indexes you’ve slapped on the ingest table.

### The key reality: per-warehouse rate is usually modest

If a “data point” = 1 row:

* 1,000,000 / 86,400 ≈ **11.6 rows/sec per warehouse**

That’s nothing.

Even **100 warehouses** is ~**1,160 rows/sec**. A properly tuned Postgres box can do that, especially with batching/COPY and sane indexing.

Where teams get crushed is **not** the row rate — it’s the **bytes, indexes, and query contention**.

---

## What actually determines whether a single node is sufficient

### 1) Data point size (this is the big one)

If each row is small and typed (say 100–300 bytes payload + overhead), you’re fine.

If each point is a chunky JSON blob (say 2–10 KB), you’re in a different world.

Rough example:

* **200 bytes/row** → 1M rows/day ≈ **200 MB/day/warehouse**
* **2 KB/row** → 1M rows/day ≈ **2 GB/day/warehouse**
* **10 KB/row** → 1M rows/day ≈ **10 GB/day/warehouse**

Now multiply by warehouse count and retention.

### 2) Retention in Postgres

If they keep only “hot” data in Postgres (e.g. 30–180 days) and push cold history to a warehouse/lake, single node stays plausible longer.

If they keep **years** of raw telemetry in Postgres, you’ll hit pain sooner — not always storage first, but vacuum/index/IO and query latency.

### 3) Indexing strategy

Two rules:

* **Every index is a write amplifier.**
* JSON + GIN everywhere is how you murder ingest.

For high-ingest telemetry, the hot table should typically have:

* one btree like `(warehouse_id, ts)` (or `(robot_id, ts)`)
* maybe a **BRIN** on `ts` if large and append-only
* everything else either computed into rollups or queried in OLAP

### 4) Read workload separation

Most “Postgres can’t keep up” stories are really:

* “analytics is hammering the primary” + “ingest is hammering the primary”

Single node often works if you:

* keep OLTP / operational queries on primary
* send dashboards and heavy reads to replicas or warehouse
* pre-aggregate what you chart constantly

### 5) Concurrency + hotspots

If all writes land in a few hot keys (same warehouse/robot row updates, counters, upserts with contention), you can get bottlenecked even at modest volumes. Append-only avoids this.

---

## When I’d say “single node isn’t enough”

You likely need sharding / multi-cluster / lakehouse when **one or more** of these are true:

* You have **hundreds to thousands of warehouses** *and* keep lots of data hot.
* Data points are **KBs each** (big JSON / derived payloads) and you retain long periods.
* You need **sub-second analytics** across *many warehouses* over large time windows on the same system.
* You require **tenant isolation / blast-radius control** (noisy neighbor), which is an architectural reason, not a raw throughput one.
* You’ve already done the basics (partitioning, batching, minimal indexes, replicas) and you’re still saturating CPU/IO.

---

## The “Dexory likely” answer

For robotics/logistics, a common winning pattern is:

* **Postgres (single cluster) for operational + recent telemetry**, partitioned by time (and often also by warehouse_id in the index strategy).
* **Read replicas** for dashboards.
* **Warehouse/lakehouse (Iceberg/Delta + Trino/Spark etc.)** for long retention + fleet-wide analytics/ML.
* **Sharding** only if OLTP workload itself outgrows one cluster or you need per-customer isolation.

So yes: a single node *can* be sufficient — **if Postgres is used for the right slice of the problem**, and the rest goes to the right place.

If you give me two numbers, I’ll tell you immediately which side they’re on:

1. **warehouses now + target in 18 months**
2. average **bytes per data point** (rough guess is fine: 200B / 2KB / 10KB) and **retention in Postgres** (days/months/years)
