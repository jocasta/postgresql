## SCALING

* **Partition first** if the big table is time-ordered and retention/vacuum/index bloat are problems.
* **Replicas + caching** if the primary is dying from reads.
* **Warehouse** if analytics is what’s hurting (dashboards, aggregates, ad-hoc).
* **Sharding** only when the app is naturally multi-tenant/site-based and you can keep most queries on one shard.
* **Iceberg/lakehouse** when you’re storing an ever-growing history of events and want cheap storage + scalable analytics, not transactional semantics.

---

## INDEX STRATEGY

2 rules:

* **Every index is a write amplifier.**
* JSON + GIN everywhere is how you murder ingest.

For high-ingest telemetry, the hot table should typically have:

* one btree like `(warehouse_id, ts)` (or `(robot_id, ts)`)
* maybe a **BRIN** on `ts` if large and append-only
* everything else either computed into rollups or queried in OLAP

---

### PG_PARTMAN

* Supported partitioning

* RANGE (most common – time-based)

* LIST (e.g. tenant / region)

* Uses native declarative partitioning (no triggers in v5)

---

## Connection Pooling - pgBouncer

connection modes ......


--- 

### Tuning for Writes

---

## Tuning for Reads

---

## Tuning for append only

---

## Analytical offloading 

---

## QUESTIONS TO ASK THEM