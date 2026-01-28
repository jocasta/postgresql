

---

### (1) ✅ All schema changes are backwards compatible first

Make changes that allow **old and new application versions to run at the same time**, so deploy order doesn’t matter and rollbacks are safe.

---

### (2) ✅ No blocking index builds (use `CONCURRENTLY`)

Create indexes with `CONCURRENTLY` so reads and writes continue while the index is built, even though it takes longer.

---

### (3) ✅ Constraints added `NOT VALID` then `VALIDATE`

Add foreign keys and checks as `NOT VALID` to avoid scanning the table under heavy locks, then validate later without blocking normal traffic.

---

### (4) ✅ Backfill data in small batches

Migrate existing data gradually using short transactions to avoid long locks, IO spikes, and replication lag.

---

### (5) ✅ Application supports old and new schema during rollout

Deploy application changes that **dual-read or dual-write** so traffic continues smoothly while data is being migrated.

---

### (6) ✅ `lock_timeout` and `statement_timeout` are set

Force migrations to fail fast instead of waiting indefinitely for exclusive locks that could stall production.

---

### (7) ✅ Contract (cleanup) only after confidence

Remove old columns, indexes, and constraints **only once you’re certain** no running code depends on them anymore.

---

### (8) ✅ Monitor during the change

Watch locks, replication lag, IO, and error rates while the migration runs so you can pause or abort before users feel it.

---

### (9) ✅ Have a rollback plan

Know in advance how to undo or bypass the change (feature flags, dual columns, skipped reads) without touching production data.

---

### (10) ✅ Prefer additive changes over destructive ones

Adding new structures is almost always safer than modifying or removing existing ones, especially on large or busy tables.

---

### !! IMPORTANT !! 

If you follow this checklist **religiously**, PostgreSQL schema changes stop being scary — outages almost always come from skipping one of these steps under time pressure.

