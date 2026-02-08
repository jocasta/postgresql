1️⃣ Architecture & decision questions (multiple choice or short answer)

Examples:

### Choosing between RDS vs Aurora

* **RDS**: 
    * simplicity 
    * predictable performance
    * lower cost
    * full engine control.
    * closer to plain postgres

* **Aurora**: 
    * higher availability
    * faster failover
    * read scaling
    * serverless elasticity.
    * shared storage

* **Aurora - wrong choice when**:
    * Cost sensitivity
    * Write-heavy or latency-sensitive workloads
    * Small or steady workloads
    “Aurora is the wrong choice when you don’t need distributed storage or fast failover — because you pay in cost, complexity, and sometimes write latency.”


### Designing Multi-AZ vs read replicas

* **Multi-AZ**: Choose for high availability and fast failover — not for scaling.
* **Read replicas**: Choose for read scaling and offloading queries — not for HA.
**Multi-AZ keeps you up**
**Read replicas help you go faster**

### Handling failover, backups, DR

* **Failover**: Automate it, test it regularly, and make application reconnection part of the design.

* **Backups**: Use automated backups plus regular restore testing — backups you can’t restore don’t count.

* **DR**: Define RPO/RTO first, then design cross-region replication and runbooks to meet them.


### Cost trade-offs (instance sizing, storage, IOPS)

* **Instance sizing**: Size for steady-state CPU and memory; scale vertically only when metrics prove it.

* **Storage**: Over-provisioning is wasted cost — choose based on growth and access patterns.

* **IOPS**: Pay for IOPS only when latency or throughput demands it; otherwise, stick with baseline performance.

---

## 2️⃣ SQL / database reasoning tasks

Query correctness

* **Indexing implications**
    * how index choices affect read performance, write overhead, storage usage, and query planning trade-offs.
* **Transaction behaviour**
    * Transaction behaviour: How the database handles concurrency, isolation, locking, and commits to ensure consistency while multiple operations run at the same time.
* **Performance impact**
    * The effect a design or change has on latency, throughput, resource usage, and overall system responsiveness.

---

## 3️⃣ Cloud database lifecycle questions

* Migrations: Safely moving data and schema changes with minimal downtime and clear rollback paths.

* Backups & restores: Ensuring data can be reliably recovered by automating backups and regularly testing restores.

* Encryption: Protecting data at rest and in transit using managed keys and strict access controls.

* Monitoring & alerting: Continuously tracking health and performance metrics with actionable alerts, not noise.

* Scaling strategies: Adjusting capacity horizontally or vertically based on workload patterns and growth needs.

--- 

## 4️⃣ Non-functional requirements translation

You may be asked:

“Given X workload, which design meets availability, performance and cost constraints?”

---

## (5)  Security & compliance (public sector focus)


* Least-privilege access

* IAM vs DB users

* Encryption

* Auditability

* Separation of duties

* Expect reasoning questions, not implementation details.

---

## (6) Indexes

#### Why would this query cause a sequential scan?

Because without a selective index on created_at, PostgreSQL must scan the entire table to find rows from the last 30 days.

### Why might an index not be used?

* The predicate isn’t selective enough (large % of table matches).

* Statistics are outdated, so the planner misestimates cost.

* The index doesn’t match the filter or grouping pattern.

* A sequential scan is cheaper than random I/O on large result sets.

#### What happens under concurrency?

* The scan runs under MVCC, so readers don’t block writers.

* High concurrency increases I/O and CPU contention.

* Long-running scans can delay vacuum, leading to table bloat over time.

