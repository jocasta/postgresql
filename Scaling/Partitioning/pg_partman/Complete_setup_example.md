Below is a **“gold-standard” pg_partman time-partitioned table** that I’d happily put into production.
It’s opinionated, boring, predictable, and easy to operate — which is exactly what you want.

I’ll assume:

* PostgreSQL 16+ (works the same on 18)
* `pg_partman`
* Native declarative partitioning
* Time-based partitions on `created_at`
* Monthly partitions (easy retention, low overhead)

---

## 1️⃣ Base table design (before partitioning)

**Rules I follow**

* Always have a **surrogate PK**
* Always have a **time column**
* Never make the time column nullable
* No business logic in partition keys

```sql
CREATE TABLE public.events (
    event_id     bigserial PRIMARY KEY,
    created_at   timestamptz NOT NULL,
    event_type   text        NOT NULL,
    payload      jsonb       NOT NULL,
    source       text        NOT NULL,
    inserted_at  timestamptz NOT NULL DEFAULT now()
);
```

---

## 2️⃣ Convert to a pg_partman-managed parent

```sql
SELECT partman.create_parent(
    p_parent_table    := 'public.events',
    p_control         := 'created_at',
    p_type            := 'native',
    p_interval        := '1 month',
    p_premake         := 3
);
```

What this does:

* Converts `events` into a partitioned table
* Creates current + 3 future monthly partitions
* Registers everything in `partman.part_config`

---

## 3️⃣ Indexing strategy (this matters)

### Golden rules

* **Indexes go on the parent**
* pg_partman propagates them
* Never index partitions manually

```sql
CREATE INDEX ON public.events (created_at);
CREATE INDEX ON public.events (event_type);
CREATE INDEX ON public.events (source);
```

Check propagation:

```sql
SELECT indexname, tablename
FROM pg_indexes
WHERE tablename LIKE 'events_%';
```

---

## 4️⃣ Retention policy (the clean way)

Example: keep **13 months**, drop the rest automatically.

```sql
UPDATE partman.part_config
SET retention = '13 months',
    retention_keep_table = false,
    retention_keep_index = false
WHERE parent_table = 'public.events';
```

Now old partitions:

* are dropped
* indexes dropped
* no VACUUM pain
* instant reclaim of disk

---

## 5️⃣ Maintenance scheduling (pg_cron)

Run every 5 minutes (safe, cheap):

```sql
SELECT cron.schedule(
  'partman_maintenance',
  '*/5 * * * *',
  $$SELECT partman.run_maintenance();$$
);
```

This:

* Creates future partitions
* Applies retention
* Reapplies constraints if needed

---

## 6️⃣ Optional: template table (advanced but excellent)

If you want **perfect control** over indexes, storage, and constraints:

```sql
SELECT partman.create_template('public.events');
```

Then modify the template:

```sql
ALTER TABLE partman.template_public_events
  SET (fillfactor = 90);

CREATE INDEX ON partman.template_public_events (event_type);
```

Apply to all partitions:

```sql
SELECT partman.refresh_template('public.events');
```

---

## 7️⃣ Sanity & inspection queries

### List partitions

```sql
SELECT * FROM partman.show_partitions('public.events');
```

### Check config

```sql
SELECT parent_table, partition_interval, premake, retention
FROM partman.part_config;
```

### Verify pruning

```sql
EXPLAIN ANALYZE
SELECT *
FROM public.events
WHERE created_at >= now() - interval '7 days';
```

You should see **only 1–2 partitions scanned**.

---

## 8️⃣ Insert pattern (nothing special required)

```sql
INSERT INTO public.events (
  created_at, event_type, payload, source
)
VALUES (
  now(), 'login', '{"user":"mike"}', 'api'
);
```

Postgres routes rows automatically.

---

## 9️⃣ What NOT to do (hard-won lessons)

❌ Partition by `now()`
❌ Daily partitions unless you *really* need them
❌ Manual partition creation
❌ Per-partition indexes
❌ Triggers for routing
❌ Huge composite PKs including timestamp

---

## 10️⃣ When I would change this design

| Scenario | Change |
| -------- | ------ |

> 1B+ rows/month | Weekly partitions |
> Hot/cold workloads | Sub-partition by hash |
> Time + tenant | Sub-partition by tenant_id |
> Analytical only | Larger partitions |
> High churn | Shorter retention |

---

## TL;DR “copy/paste minimal version”

```sql
CREATE TABLE events (
  event_id bigserial PRIMARY KEY,
  created_at timestamptz NOT NULL,
  event_type text NOT NULL,
  payload jsonb NOT NULL
);

SELECT partman.create_parent(
  'public.events',
  'created_at',
  'native',
  '1 month'
);

CREATE INDEX ON events (created_at);
CREATE INDEX ON events (event_type);

UPDATE partman.part_config
SET retention = '13 months'
WHERE parent_table = 'public.events';
```

---

If you want next:

* **daily vs monthly decision table**
* **partman vs native only**
* **how to migrate a large existing table**
* **TimescaleDB equivalent of this pattern**

Say which direction you want to go.
