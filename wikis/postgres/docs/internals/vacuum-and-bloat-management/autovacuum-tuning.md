# Autovacuum triggering, throttling and tuning

## When a table gets vacuumed

```
vacuum   if  n_dead_tup  > autovacuum_vacuum_threshold (50)
                         + autovacuum_vacuum_scale_factor (0.2) × reltuples
vacuum   if  n_ins_since_vacuum > autovacuum_vacuum_insert_threshold (1000)
                                + autovacuum_vacuum_insert_scale_factor (0.2) × reltuples   -- PG13+
analyze  if  n_mod_since_analyze > autovacuum_analyze_threshold (50)
                                 + autovacuum_analyze_scale_factor (0.1) × reltuples
```

PG18 adds `autovacuum_vacuum_max_threshold` (default 100M) to cap the dead-tuple threshold on huge tables.

With the default 20% scale factor, a 1-billion-row table waits for 200M dead rows — far too late. Set per-table:

```sql
ALTER TABLE events SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_vacuum_threshold    = 10000,
    autovacuum_analyze_scale_factor = 0.02
);
```

## Cost-based throttling

Vacuum accumulates "cost" for page work and sleeps when it hits the limit:

| Setting | Default | |
|---|---|---|
| `vacuum_cost_page_hit` | 1 | Page found in shared buffers |
| `vacuum_cost_page_miss` | 2 | Page read from disk (was 10 before PG14) |
| `vacuum_cost_page_dirty` | 20 | Page dirtied |
| `autovacuum_vacuum_cost_limit` | -1 → `vacuum_cost_limit` (200) | Budget per round — **shared across all running workers** |
| `autovacuum_vacuum_cost_delay` | 2 ms | Sleep when budget used |

Default throughput is low for modern storage. Typical tuning for busy systems:

```ini
autovacuum_max_workers = 6
autovacuum_vacuum_cost_limit = 2000
autovacuum_naptime = 15s
maintenance_work_mem = 1GB      # or autovacuum_work_mem
log_autovacuum_min_duration = 0  # log every autovacuum run (PG15+ default 10min)
```

```sql
-- Who needs vacuum, and when did it last run?
SELECT relname, n_live_tup, n_dead_tup,
       round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
       last_autovacuum, last_autoanalyze, autovacuum_count
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 20;
```
