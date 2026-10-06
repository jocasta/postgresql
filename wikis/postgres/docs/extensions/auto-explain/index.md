# auto_explain

Automatically logs the execution plan of statements that exceed a duration threshold — captures the *actual* plan used in production.

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** Yes for all sessions (or `LOAD 'auto_explain';` for one session)
- **Docs:** <https://www.postgresql.org/docs/current/auto-explain.html>

---

## Install

There is no `CREATE EXTENSION` — it's a loadable module only.

```ini
# postgresql.conf
shared_preload_libraries = 'pg_stat_statements,auto_explain'   # restart
# or: session_preload_libraries = 'auto_explain'                # new sessions, no restart

auto_explain.log_min_duration = '500ms'   # -1 disables, 0 logs everything
auto_explain.log_analyze = on             # actual rows/timings (adds overhead to ALL statements)
auto_explain.log_buffers = on             # requires log_analyze
auto_explain.log_timing = off             # per-node timing is the expensive bit
auto_explain.log_nested_statements = on   # include statements inside functions
auto_explain.log_format = 'text'          # text | json | yaml | xml
auto_explain.sample_rate = 1.0            # 0.0–1.0, sample a fraction of sessions
```

Ad-hoc in a single session:

```sql
LOAD 'auto_explain';
SET auto_explain.log_min_duration = 0;
SET auto_explain.log_analyze = on;
-- run the query, then check the server log
```

---

## Settings reference

| Setting | Default | Notes |
|---|---|---|
| `log_min_duration` | `-1` | Threshold to log a plan |
| `log_analyze` | `off` | `EXPLAIN ANALYZE` output — instruments every statement |
| `log_buffers` | `off` | Buffer usage |
| `log_wal` | `off` | WAL usage (PG13+) |
| `log_timing` | `on` | Per-node timing; turn off to cut overhead |
| `log_triggers` | `off` | Trigger stats |
| `log_verbose` | `off` | `EXPLAIN VERBOSE` |
| `log_settings` | `off` | Non-default planner settings (PG12+) |
| `log_parameter_max_length` | `-1` | Log bind parameters (PG16+) |
| `log_nested_statements` | `off` | Statements inside functions |
| `log_level` | `log` | Log level used |
| `sample_rate` | `1` | Fraction of statements explained |

---

## Gotchas

- `log_analyze = on` adds instrumentation overhead to *every* statement, not just the slow ones. Use `log_timing = off` and/or `sample_rate` on busy systems.
- On RDS / Aurora, add `auto_explain` to `shared_preload_libraries` in the parameter group; output goes to the PostgreSQL log (CloudWatch if exported).
- JSON format pairs well with plan visualisers (e.g. <https://explain.dalibo.com>).
