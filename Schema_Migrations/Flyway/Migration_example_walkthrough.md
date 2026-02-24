If you want **PostgreSQL schema changes without downtime**, you need two things:

### 1. **Techniques that avoid long AccessExclusive locks**
### 2. An **expand → migrate → contract** deployment pattern so old + new app versions both work during the transition

Here’s the playbook that actually works in production.

---

## The golden rule: Expand → Migrate → Contract

### 1) Expand (safe, backwards-compatible)

Add new things without breaking the old app:

* Add nullable columns
* Add new tables
* Add indexes **CONCURRENTLY**
* Add constraints as **NOT VALID**
* Add new enum values carefully (see below)

### 2) Migrate (data + dual-write if needed)

* Backfill data in batches
* Keep old and new columns in sync (app dual-write or triggers)
* Roll out code that reads from new structure

### 3) Contract (cleanup, once everything uses new shape)

* Drop old columns
* Drop old indexes
* Validate constraints
* Tighten NOT NULL, defaults, etc.

This is how you keep changes deployable with **no hard cutover**.

---

## Operations that are “usually safe” (low-lock)

### Add a nullable column

```sql
ALTER TABLE t ADD COLUMN new_col text;
```

Fast and typically safe.

### Create index without blocking writes

```sql
CREATE INDEX CONCURRENTLY idx_t_new_col ON t(new_col);
```

Takes longer, but avoids blocking.

### Add FK/check constraint without blocking writes

```sql
ALTER TABLE child
  ADD CONSTRAINT child_parent_fk
  FOREIGN KEY (parent_id) REFERENCES parent(id)
  NOT VALID;

ALTER TABLE child VALIDATE CONSTRAINT child_parent_fk;
```

`NOT VALID` avoids a big lock up front; validation runs without blocking normal traffic (still takes some locks, but not a full outage).

---

## The biggest foot-guns (avoid / workaround)

### 1) `ALTER TABLE ... SET NOT NULL` on a big table

Can take long locks (and scans).

**Better pattern**

* Add a CHECK constraint `NOT VALID`
* Backfill
* Validate
* Then set NOT NULL during a quiet window (often quick once clean)

Example:

```sql
ALTER TABLE t ADD CONSTRAINT t_new_col_nn CHECK (new_col IS NOT NULL) NOT VALID;
ALTER TABLE t VALIDATE CONSTRAINT t_new_col_nn;
-- later: ALTER TABLE t ALTER COLUMN new_col SET NOT NULL;
```

### 2) Adding a DEFAULT that rewrites the table (older PG)

Older Postgres versions rewrote the whole table for `ADD COLUMN ... DEFAULT ...`. Newer versions optimize many cases, but you’re on mixed estates often.

**Safe approach**

* Add column nullable with no default
* Backfill
* Add default later if needed

### 3) Dropping/renaming columns your app still uses

This is why expand/contract exists. Never “rename in place” in one deploy.

---

## Patterns you’ll use constantly

### Rename a column with no downtime

**Don’t rename.** Create new + migrate.

1. Expand:

```sql
ALTER TABLE t ADD COLUMN new_name text;
```

2. Migrate (batch backfill):

```sql
UPDATE t
SET new_name = old_name
WHERE new_name IS NULL
LIMIT ...;  -- do batches in app/job
```

3. Dual-write (app writes both) for a release

4. Cut reads to new_name

5. Contract:

```sql
ALTER TABLE t DROP COLUMN old_name;
```

### Change a column type (e.g., int → bigint)

Same pattern. Add new column with new type, backfill, dual-write, switch reads, drop old.

---

## How to backfill without hurting production

Backfills are where people accidentally DOS their own database.

* Do it in **small batches**
* Commit each batch
* Sleep between batches
* Drive it by primary key ranges
* Monitor replication lag / IO / locks

If you need a template, say what table/PK you have and I’ll give you a safe batch script.

---

## Use lock timeouts so migrations fail fast instead of taking prod down

In your migration session:

```sql
SET lock_timeout = '2s';
SET statement_timeout = '5min';
```

This prevents a migration from waiting forever for an AccessExclusive lock.

---

## Online table rewrites (when you truly must rewrite)

Some changes inherently rewrite the table (big lock risk). Options:

* Use `pg_repack` (if allowed) for online rewrite-ish behaviour
* Build a new table, dual-write, then swap (heavy but safe)
* Partitioning migrations often need a “new table + swap” approach

---

## Version control your database changes

Use something like Flyway/Liquibase and treat migrations as deployable units:

* Schema migration
* Code migration
* Data migration (backfill)
* Cleanup migration

---

## The “no downtime” checklist

* ✅ All schema changes backwards compatible first
* ✅ No blocking index builds (use CONCURRENTLY)
* ✅ Constraints added NOT VALID then VALIDATE
* ✅ Backfill in batches
* ✅ App can run with both old/new schema during rollout
* ✅ lock_timeout + statement_timeout set
* ✅ Contract cleanup only after you’re sure

---

If you tell me:

* Postgres version (you mentioned 14.20 in one place, Aurora elsewhere)
* The exact change you’re planning (rename? type change? partitioning? FK?)
* Table size / write rate

…I’ll map it to a concrete, step-by-step migration plan that won’t block prod.
