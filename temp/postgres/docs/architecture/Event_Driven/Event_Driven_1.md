https://medium.com/@ArkProtocol1/postgres-18-just-swallowed-mongodb-why-you-no-longer-need-nosql-83051ca49a27

### Documents With Guardrails

Here is the pattern that replaces a NoSQL service for a lot of teams now.

Store the full JSON document so the product can evolve.
Extract a small set of truth fields for indexing, constraints, and stable queries.

You keep the flexibility.
You stop paying the price in inconsistency.

A simple example looks like this:

```sql

-- EVENT TABLE
create table evt (
  id uuid primary key default uuidv7(),
  doc jsonb not null,
  kind text generated always as (doc->>'type') virtual,
  ts  timestamptz generated always as ((doc->>'ts')::timestamptz) virtual
);

-- INDEXES
create index on evt (kind, ts);
create index evt_doc_gin on evt using gin (doc);

-- SAMPLE SELECT
select id, doc->>'userId' as u
from evt
where kind = 'payment'
  and ts >= now() - interval '7 days'
  and doc @> '{"status":"ok"}';
```

**That query reads like a document store, but it runs inside one transactional system with constraints and joins when you need them.**

It also gives you one backup story.
One permission model.
One operational brain.

**You still scale with partitions and replicas when you need them.**

We compared two setups for an events table with a JSONB payload and an index on the primary key.

Here is what we saw on the same machine, same dataset shape, same write rate target.

```
Workload: 10M Inserts, Jsonb Payload, 1 Primary Index

Key Type     p95 Insert Latency   Index Growth Feel
Uuidv4       Higher              More page churn
Uuidv7       Lower               Smoother, steadier
```