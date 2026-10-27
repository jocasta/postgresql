# What's Actually Inside PostgreSQL's Memory? Meet pg_buffercache

!!! info "Source"
    **techybob** on Medium · 25 Oct 2026 · 9 min read ·
    [Original article](https://medium.com/@techybob/whats-actually-inside-postgresql-s-memory-meet-pg-buffercache-6f949e303170)

**pg_buffercache lets you look inside PostgreSQL's shared buffers and see which relations occupy them. But a cache snapshot is evidence, not a performance diagnosis.**

![pg_buffercache](images/whats-inside-postgresql-memory-1.png)

The PostgreSQL server has plenty of memory.

So why is the query still slow?

Imagine this.

Your production database has:

```ini
shared_buffers = 16GB
```

Someone checks the database statistics.

> *"Cache hit ratio is 99%. Memory isn't the problem."*

Case closed?

Not quite.

A 99% hit ratio tells you something useful about buffer accesses.

But it doesn't tell you:

- What is occupying PostgreSQL's shared buffers right now?
- How much of a specific table or index is currently cached?
- Whether your important working set is competing with another workload
- Whether the slow query is actually an I/O problem at all

Maybe a frequently used index occupies only a small portion of the cache while an analytical workload is cycling through a much larger dataset.

Or perhaps the opposite is happening.

Maybe the data you need is already cached, and the query is slow because it's processing millions of rows, performing an expensive join, or sorting a huge intermediate result.

That's the distinction that matters:

> **Cached does not automatically mean fast. And a cache miss does not automatically mean disk is the bottleneck.**

So how do we look inside PostgreSQL's shared-buffer cache?

Meet `pg_buffercache`.

## What Is pg_buffercache?

PostgreSQL uses shared buffers to hold database pages in memory.

Those buffers can contain pages belonging to tables, indexes, and other relations.

The `pg_buffercache` module provides a way to examine what's happening in that shared buffer cache in real time. Its main view contains one row for each buffer in the shared cache.

Conceptually:

```text
                PostgreSQL
                    │
                    ▼
              shared_buffers
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
    Table Pages  Index Pages  Other Pages
        │           │           │
        └───────────┼───────────┘
                    │
                    ▼
              pg_buffercache
                    │
                    ▼
          What is cached NOW?
```

That gives us a different kind of observability.

Instead of asking only:

> *"What is my cache-hit ratio?"*

we can start asking:

> *"What is actually occupying the cache?"*

According to the official documentation, the module exposes information including the relation file node, tablespace, database, block number, whether a page is dirty, its usage count, and the number of backends pinning the buffer.

## Step 1: Enable the Extension

In the database you want to investigate:

```sql
CREATE EXTENSION IF NOT EXISTS pg_buffercache;
```

Assuming the module is available in the PostgreSQL installation and your environment allows it, this makes its views and functions available.

Access is restricted by default.

The current PostgreSQL documentation says the inspection functions are available to superusers and roles with privileges of the predefined `pg_monitor` role, although access can also be explicitly granted. Buffer-eviction functions have stronger restrictions.

That's sensible.

This isn't functionality that should casually be handed to every application account.

## Step 2: Don't Start with Every Buffer

You could immediately examine the entire cache.

But I'd start simpler.

```sql
SELECT
buffers_used,
buffers_unused,
buffers_dirty,
buffers_pinned,
usagecount_avg
FROM pg_buffercache_summary();
```

This gives you an at-a-glance picture of shared buffers.

```text
buffers_used
└── How many buffers are currently used?

buffers_unused
└── How many buffers are still unused?

buffers_dirty
└── How many contain modified pages?

buffers_pinned
└── How many are currently pinned?

usagecount_avg
└── What is the average usage count
    of the used buffers?
```

These fields are defined by the `pg_buffercache_summary()` function in PostgreSQL.

And there is an important operational reason to start here.

`pg_buffercache_summary()` is documented as being significantly cheaper than examining the more detailed `pg_buffercache` view.

Think of it like this:

```text
Need cache information?
        │
        ▼
Start with summary
        │
        ▼
Something interesting?
    ┌───┴───┐
    │       │
   NO      YES
    │       │
    ▼       ▼
 Stop    Inspect deeper
```

One more detail matters.

Neither the summary function nor the main view acquires buffer-manager locks while collecting this information. As a result, concurrent database activity can cause minor inaccuracies in the snapshot.

In other words:

> **Treat the result as an observation of a moving system, not an accounting ledger.**

## Step 3: Which Relations Are Occupying the Cache?

Now we can ask the more interesting question.

Which tables and indexes currently occupy the most PostgreSQL shared buffers?

For example:

```sql
WITH current_db AS (
SELECT oid, dattablespace
FROM pg_database
WHERE datname = current_database()
)
SELECT
c.oid::regclass AS relation,
c.relkind,
COUNT(*) AS cached_pages,
pg_size_pretty(
COUNT(*) * current_setting('block_size')::bigint
) AS cached_size
FROM pg_buffercache b
JOIN current_db d
ON b.reldatabase = d.oid
JOIN pg_class c
ON b.relfilenode = pg_relation_filenode(c.oid)
AND b.reltablespace =
CASE
WHEN c.reltablespace = 0
THEN d.dattablespace
ELSE c.reltablespace
END
WHERE c.relkind IN ('r', 'i', 'm', 't')
GROUP BY c.oid, c.relkind
ORDER BY COUNT(*) DESC
LIMIT 20;
```

Now we're no longer asking:

> *How full is shared_buffers?*

We're asking:

```text
                 SHARED BUFFERS
                       │
          ┌────────────┼────────────┐
          │            │            │
          ▼            ▼            ▼
       orders      orders_idx    customer
          │            │            │
          ▼            ▼            ▼
      ? cached      ? cached      ? cached
```

This distinction can be extremely useful during an investigation.

### But Be Careful with Relation Mapping

There is an important caveat when joining `pg_buffercache` to `pg_class`.

PostgreSQL's buffer cache is shared across databases. Therefore, the cache can contain pages belonging to databases other than the one you're currently connected to.

The PostgreSQL documentation specifically recommends restricting joins to the current database's OID, or database zero for shared system catalogs, because otherwise rows may not join correctly and incorrect matches can even be possible.

So don't treat `relfilenode` by itself as the universal identity of a table.

Context matters.

## Step 4: Look at Individual Cached Pages

Sometimes the relation-level picture isn't enough.

We can go deeper:

```sql
SELECT
bufferid,
relfilenode,
reltablespace,
relforknumber,
relblocknumber,
isdirty,
usagecount,
pinning_backends
FROM pg_buffercache
WHERE relfilenode IS NOT NULL
ORDER BY usagecount DESC
LIMIT 50;
```

Now we're looking at individual shared-buffer entries.

The official view exposes fields such as:

- `bufferid`
- `relfilenode`
- `reltablespace`
- `reldatabase`
- `relforknumber`
- `relblocknumber`
- `isdirty`
- `usagecount`
- `pinning_backends`

`usagecount` is PostgreSQL's clock-sweep access count, while `bufferid` identifies a slot in the shared-buffer array.

Don't interpret:

```text
usagecount = 5
```

as:

> *"This page was accessed five times."*

That's not what the field means.

And don't treat `bufferid` as a permanent identifier for some database block.

It's identifying the current shared-buffer slot.

## Step 5: Now Connect Cache Evidence to the Slow Query

This is the most important part of the investigation.

Suppose this dashboard query is slow:

```sql
SELECT
customer_id,
COUNT(*)
FROM orders
WHERE created_at >= current_date - 7
GROUP BY customer_id;
```

You inspect `pg_buffercache` and discover that a substantial amount of `orders` is currently resident in shared buffers.

Case closed?

No.

Now run the investigation from the query's perspective:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
customer_id,
COUNT(*)
FROM orders
WHERE created_at >= current_date - 7
GROUP BY customer_id;
```

Be careful in production because `EXPLAIN ANALYZE` actually executes the statement.

Now we have two different perspectives:

```text
        pg_buffercache
              │
              ▼
 What's in shared buffers?
              │
              │
              ▼
       Compare Evidence
              ▲
              │
              │
 EXPLAIN (ANALYZE, BUFFERS)
              │
              ▼
 What did THIS query actually do?
```

That's far more useful.

## The Cache-Hit-Ratio Trap

Here's where PostgreSQL investigations often go wrong.

Someone sees:

```text
Cache Hit Ratio = 99%
```

and concludes:

```text
Memory is fine
      ↓
Disk isn't involved
      ↓
Look somewhere else
```

That's too simplistic.

Imagine Query A touches:

```text
100 cached pages
```

and Query B touches:

```text
2,000,000 cached pages
```

Both could have an excellent hit ratio.

But processing millions of cached pages can still require substantial CPU and memory bandwidth and can feed expensive joins, aggregates, and sorts.

So:

```text
            HIGH CACHE HIT RATIO
                    │
                    ▼
              Useful signal
                    │
                    ▼
          But NOT proof of:
                    │
       ┌────────────┼─────────────┐
       ▼            ▼             ▼
 Query is fast   Plan is good   I/O irrelevant
```

The ratio is one piece of evidence.

Not the diagnosis.

## Another Trap: "Cache Miss = Physical Disk"

PostgreSQL's shared-buffer cache isn't the only caching layer in the system.

Conceptually:

```text
         PostgreSQL Query
                │
                ▼
          Shared Buffers
                │
          Page available?
          ┌─────┴─────┐
          │           │
         YES          NO
          │           │
          ▼           ▼
        Use it    Request page
                      │
                      ▼
                  OS Cache
                      │
                  ┌───┴───┐
                  │       │
                 HIT     MISS
                  │       │
                  ▼       ▼
                Memory   Storage
```

So a PostgreSQL shared-buffer miss shouldn't automatically be translated into:

> *"We performed slow physical disk I/O."*

There is another caching layer to consider.

This is exactly why a single number rarely explains a PostgreSQL performance problem.

## What Could the Investigation Reveal?

Suppose a report is slow.

There are several possibilities.

### Scenario 1: Useful data isn't sufficiently resident

The workload's useful working set could be competing with other activity.

Investigate:

- Concurrent workloads
- Tables being scanned
- Index access
- Storage behavior
- Cache observations over representative windows

### Scenario 2: Data is cached, but the query still reads too much

Now the problem may be:

```text
Poor predicate selectivity
      ↓
Huge number of pages
      ↓
Huge number of rows
      ↓
Expensive processing
```

An index or query redesign might be more relevant than adding memory.

### Scenario 3: The query needs a huge sort or hash

The slow part might have little to do with table pages being cached.

Investigate the execution plan.

### Scenario 4: Another workload is changing the cache

A large analytical scan could be interacting with the same shared-buffer pool as your transactional workload.

But even then, don't simply observe two relations and declare:

> *"Table A evicted Table B."*

`pg_buffercache` shows the state of the cache. It doesn't independently establish the complete causal history that produced that state.

## What pg_buffercache Can and Cannot Tell You

This distinction is worth remembering.

**pg_buffercache CAN help answer:**

- ✓ What's in shared buffers right now?
- ✓ Which relation does a cached page belong to?
- ✓ Is a cached page dirty?
- ✓ What's its usage count?
- ✓ How many backends are pinning it?

But:

**pg_buffercache ALONE cannot prove:**

- ✗ Why my query is slow
- ✗ Which query loaded every cached page
- ✗ That adding memory will fix performance
- ✗ That a cache miss means physical disk I/O
- ✗ That the biggest cached table is the problem

The PostgreSQL documentation describes `pg_buffercache` as a means of examining what's happening in the shared buffer cache in real time. That framing is important. It is an observability mechanism, not an automatic performance verdict.

## A Better PostgreSQL Memory Investigation

When someone tells me:

> *"The query is slow. Maybe PostgreSQL needs more memory."*

I wouldn't start by increasing `shared_buffers`.

I'd investigate in this order:

```text
QUERY IS SLOW
      │
      ▼
EXPLAIN (ANALYZE, BUFFERS)
      │
      ▼
What work did it do?
      │
      ▼
pg_buffercache_summary()
      │
      ▼
What does the cache look like?
      │
      ▼
pg_buffercache
      │
      ▼
Which relations occupy it?
      │
      ▼
Compare with query access pattern
      │
      ▼
Storage + concurrency + waits
      │
      ▼
FORM HYPOTHESIS
      │
      ▼
TEST CHANGE
      │
      ▼
MEASURE
```

Notice where this ends:

**Measure.**

Not:

```sql
ALTER SYSTEM SET shared_buffers = …
```

Increasing memory before proving a memory problem is just another form of guessing.

## One More Interesting Feature

Current PostgreSQL `pg_buffercache` documentation also exposes functions for evicting individual buffers, all unpinned buffers belonging to a relation, or all unpinned buffers from the buffer pool. PostgreSQL explicitly describes this as low-level functionality for testing purposes, and these eviction operations are restricted to superusers.

That distinction matters.

I would not turn a production investigation into:

> *"Let's evict this table from cache and see what happens."*

Cache manipulation can fundamentally alter the workload you're trying to observe.

Use testing functionality in a controlled environment.

## Production Checklist

When using `pg_buffercache` to investigate a performance issue:

### 1. Start with the query

Capture:

```sql
EXPLAIN (ANALYZE, BUFFERS)
```

when it is safe and appropriate to execute the statement.

### 2. Look at the shared-buffer summary

Use:

```sql
SELECT * FROM pg_buffercache_summary();
```

The summary is significantly cheaper than inspecting the full view.

### 3. Identify the relations occupying the cache

Then compare that with the slow query's actual access pattern.

### 4. Remember that you're looking at a moving system

The view doesn't lock the buffer manager to create a globally consistent cache snapshot, so concurrent activity can produce minor inconsistencies across the overall result.

### 5. Check beyond PostgreSQL shared buffers

Investigate storage latency, operating-system caching, concurrency, CPU, waits, query plans, and actual workload behavior.

### 6. Repeat during a representative workload

One snapshot at 2:00 PM doesn't necessarily explain what happened at 10:00 AM.

### 7. Change configuration only when the evidence supports it

Don't follow:

```text
Slow Query
    ↓
Must need more RAM
    ↓
Increase shared_buffers
```

Follow:

```text
Slow Query
    ↓
Measure
    ↓
Inspect Plan
    ↓
Inspect Cache
    ↓
Correlate Evidence
    ↓
Form Hypothesis
    ↓
Test
    ↓
Measure Again
```

## Final Thought

PostgreSQL using memory is normal.

A high cache-hit ratio is useful.

A table occupying a large percentage of shared buffers can also be useful information.

But none of those facts, by themselves, explain why a query is slow.

`pg_buffercache` gives you something more valuable:

> **visibility into what PostgreSQL's shared-buffer cache contains at the moment you inspect it.**

Combine that with execution-plan evidence, buffer statistics, workload behavior, and storage measurements.

So the next time someone asks:

> *"PostgreSQL has 16 GB of shared buffers. Why is it still slow?"*

Don't ask only:

> *"How much memory is PostgreSQL using?"*

Ask:

> **"What's actually in that memory, what did this query touch, and does the evidence show that caching is really the problem?"**

That's a much better place to start.
