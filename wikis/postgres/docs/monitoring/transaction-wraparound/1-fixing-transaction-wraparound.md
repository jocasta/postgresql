If that query is showing **~80%**, treat it as **“drop what you’re doing and get vacuum/freeze under control”**. You’re not dead yet, but you’re close enough that a bad day (long transactions + heavy write load) can push you into emergency mode.

### 1) First: confirm what’s actually at risk

Find the worst offenders and whether they’re *actually vacuuming*:

```sql
SELECT
  c.oid::regclass AS table_name,
  age(c.relfrozenxid) AS xid_age,
  pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
  s.last_autovacuum,
  s.last_vacuum,
  s.n_dead_tup,
  s.n_live_tup
FROM pg_class c
LEFT JOIN pg_stat_all_tables s ON s.relid = c.oid
WHERE c.relkind IN ('r','m')
ORDER BY xid_age DESC
LIMIT 25;
```

If the top tables have **no recent autovacuum** and big `n_dead_tup`, you’ve found the problem.

### 2) Check for the #1 blocker: long-running transactions

Long transactions prevent vacuum from advancing the “oldest needed XID”.

```sql
SELECT pid, usename, datname, state,
       now() - xact_start AS xact_age,
       query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_age DESC
LIMIT 20;
```

**Fix:** stop/kill the offenders (idle-in-transaction, stuck ETL jobs), and set guardrails:

* `idle_in_transaction_session_timeout`
* reasonable statement timeouts for analytics jobs

### 3) Immediate remediation: force freeze vacuum on the worst tables

Start with the highest `xid_age` table(s). Do this in a controlled order because it can be I/O heavy.

```sql
VACUUM (FREEZE, VERBOSE, ANALYZE) big_table;
```

If it’s massive, do it off-peak and expect it to take time. On a 1B-row table this can be heavy but it’s the correct “get safe” move.

**If you can’t afford analyze:**

```sql
VACUUM (FREEZE, VERBOSE) big_table;
```

### 4) Make autovacuum able to keep up (most common root cause)

On large/high-write tables, defaults are often too timid.

Per-table tuning (safer than global changes):

```sql
ALTER TABLE big_table SET (
  autovacuum_vacuum_scale_factor = 0.01,
  autovacuum_analyze_scale_factor = 0.02,
  autovacuum_vacuum_threshold = 50000,
  autovacuum_analyze_threshold = 50000,
  autovacuum_vacuum_cost_limit = 2000
);
```

Interpretation:

* scale factors lower → vacuum triggers sooner on huge tables
* thresholds stop vacuum from running constantly on tiny churn
* cost limit lets it work harder (at the cost of more IO)

### 5) If the table is append-heavy: consider partitioning

This is the long-term win for wraparound safety:

* vacuum/freeze happens per partition (smaller)
* you can “age out” old partitions (drop them)
* reduces bloat and makes maintenance predictable

### 6) Verify progress

Re-run your risk query and also watch the system view:

```sql
SELECT datname, age(datfrozenxid) AS db_xid_age
FROM pg_database
ORDER BY db_xid_age DESC;
```

And check freeze settings:

```sql
SHOW autovacuum_freeze_max_age;
SHOW vacuum_freeze_min_age;
SHOW vacuum_freeze_table_age;
```

### 7) If you’re on managed service (Crunchy Bridge / RDS etc.)

You may not control every parameter, but you can always:

* identify/kill long transactions
* run `VACUUM (FREEZE)` on the hot tables
* set **per-table autovacuum settings**
* partition + retention

---

### What usually caused “80%” in real life

* autovacuum can’t keep up on a **monster table**
* long-running “idle in transaction” sessions
* autovacuum settings left at defaults during rapid growth
* heavy update/delete churn creating dead tuples

If you paste the **top 5 tables** from the first query (table name + xid_age + size + last_autovacuum), I’ll tell you the most likely quickest path (and which ones to freeze first).
