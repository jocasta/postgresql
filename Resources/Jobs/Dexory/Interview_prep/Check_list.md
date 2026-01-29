Great role to be interviewing for — and it lines up *very* closely with what you already do day-to-day.

I’ll break this into three parts:

1. **Key technical topics to revise (mapped directly to the job spec)**
2. **Likely interview questions you’ll be asked (and what they’re really testing)**
3. **Strong questions *you* should ask them (to stand out as a senior hire)**

Everything below is grounded in the job description you uploaded  and tailored to a **Senior PostgreSQL DBA in a fast-scaling, data-heavy robotics platform**.

---

## 1. Technical topics to revise (priority order)

### A. Scaling PostgreSQL at TB scale (this is the core of the role)

You should be **very crisp** on *when* and *why* you’d choose each option:

**Partitioning**

* Native declarative partitioning (range / list / hash)
* Partition pruning (planner behaviour)
* Indexes on parent vs partitions
* Hot vs cold partitions
* Partition management tooling (pg_partman, custom jobs)
* Migrating an already-large unpartitioned table → partitioned (online strategy)

**Sharding**

* When Postgres partitioning stops being enough
* Application-level sharding vs logical sharding
* Trade-offs: joins, transactions, operational complexity
* Tools/approaches: Citus, manual shard routing, read replicas
* Why sharding is often a *last resort*

**Analytical offloading**

* When OLTP Postgres becomes the wrong tool
* Data warehousing patterns:

  * Iceberg / lakehouse concepts
  * Columnar stores vs Postgres
* Near-real-time vs batch analytics
* What *stays* in Postgres vs what gets exported

👉 Expect *opinionated* discussion here — they explicitly want strong views.

---

### B. Query performance & index strategy

You should revise:

* Reading `EXPLAIN (ANALYZE, BUFFERS)`
* Identifying:

  * Bad join orders
  * Nested loop disasters
  * Bitmap vs index scans
* Index types:

  * B-tree vs BRIN (very relevant for time-series / append-only data)
  * Partial indexes
  * Covering indexes (`INCLUDE`)
* Index bloat and maintenance trade-offs
* When *not* to add an index

They will want to hear **how you decide**, not just what commands you run.

---

### C. High-write workloads

Given robotics + telemetry style data, expect:

* Write amplification
* WAL pressure
* Autovacuum tuning:
  * scale factors vs thresholds
  * aggressive vacuum on hot tables only
* Fillfactor
* HOT updates
* Batch inserts vs single-row inserts
* Impact of indexes on write throughput

---

### D. Connection management & pooling

They explicitly list this.

Revise:

* PgBouncer modes (session / transaction / statement)
* Why transaction pooling breaks some workloads
* Pool sizing relative to:
  * CPU cores
  * Active queries
* Symptoms of too many connections vs too few
* Application-side vs infra-side pooling

---

### E. Monitoring, alerting & regression detection

You should be fluent in:

* Key Postgres metrics:
  * TPS, latency
  * Cache hit ratio
  * Dead tuples
  * Autovacuum lag
* Query regression detection
* Slow query logging strategy
* Alert fatigue vs actionable alerts
* Capacity planning signals (what trends actually matter)

You don’t need to name specific tools unless asked — focus on **what you watch and why**.

---

### F. Backup, recovery & incident response

Revise:

* PITR mechanics (WAL, base backups)
* Backup validation strategies
* Restore time objectives vs backup frequency
* Handling operator error (bad deploy, dropped index, etc.)
* On-call mindset: fast containment vs perfect fix

---

### G. Working with developers (very important)

They clearly expect collaboration.

Be ready to talk about:

* Reviewing schemas before they hit prod
* Migration safety (locking, long-running DDL)
* Educating devs without being obstructive
* Saying “no” constructively
* Owning DB health while enabling velocity

---

## 2. Likely interview questions (and what they’re testing)

### Scaling & architecture

> “We have a table growing by X GB per week — what do you do first?”

They want:

* Clarifying questions
* Partitioning before sharding
* Index + query review before infra changes

---

> “How would you migrate a large live table to partitioned?”

They’re testing:

* Online migration thinking
* Risk awareness
* Operational experience

---

> “When would you move data *out* of Postgres?”

They want maturity:

* Acknowledge Postgres limits
* Cost/performance trade-offs
* Clear ownership boundaries

---

### Performance

> “A query suddenly got 10x slower — what’s your process?”

They’re testing:

* Methodical debugging
* Metrics first, not guesswork
* Rollback mindset

---

> “What’s your approach to index sprawl?”

They want to hear:

* Indexes are not free
* Measurement-based decisions
* Periodic pruning
* Rebuild concurrently

---

### Operations

> “How do you design alerting without waking people up unnecessarily?”

They want:

* Signal > noise
* Trend-based alerts
* SLO-style thinking

---

### Behavioural / seniority

> “Tell us about a time you disagreed with an engineering team.”

They want:

* Calm authority
* Trade-off explanation
* Outcome focus, not ego

* Sizing CPU / RAM incorrectly rather than tuning properly

---

## 3. Smart questions *you* should ask them

These matter — senior candidates are evaluated on this.

### About scale & data

* “What are your fastest-growing tables today, and what drives that growth?”
* “Is your workload primarily append-only, or do you have heavy updates?”
* “How close are you to Postgres becoming a bottleneck today?”

### Current deployment:

* on-prem / cloud
* Containers / VMs 
* OS
* Clustered? Replicas
* Auto Failover? 

### About architecture direction

* “What’s already been tried for scaling, and what didn’t work?”
* “How open are you to offloading analytics to a separate system long-term?”
* “Is sharding on the roadmap, or something you’re hoping to avoid?”

### About ownership & influence

* “How much authority does this role have over schema and query decisions?”
* “At what stage do DBAs get involved in feature design today?”
* “What does success look like in the first 6 months?”

### About on-call & incidents

* “How frequent are DB-related incidents currently?”
* “What’s the on-call expectation and escalation path?”
* “Do you do post-incident reviews, and are they blameless?”

### About culture (important at a scale-up)

* “How do you balance rapid iteration with long-term data health?”
* “What’s the biggest technical risk you see in the platform right now?”

---

## Final coaching note (important)

This role is **not** looking for:

* Someone who just “keeps Postgres running”
* A passive caretaker

They want:

* **Strong opinions**
* **Battle-tested trade-offs**
* Someone who can say:
  *“Here’s what I’d do, here’s why, and here’s the risk.”*

That already matches how you think — the key is to **say it confidently and concisely**.

If you want, next we can:

* Do a **mock interview**
* Turn this into a **1-page revision checklist**
* Practice **explaining partitioning/sharding to non-DBAs**
* Craft a **30-60-90 day plan** for this role

Just tell me how you want to prep next.
