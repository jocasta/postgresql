# auto_explain: Introduction

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** Yes for all sessions (or `LOAD 'auto_explain';` for one session)
- **Docs:** <https://www.postgresql.org/docs/current/auto-explain.html>

## What it does

auto_explain automatically writes the execution plan of any statement that runs longer than a threshold
(`auto_explain.log_min_duration`) to the server log. Unlike running `EXPLAIN` by hand afterwards, it captures the *actual*
plan chosen at the time — with real row counts, timings and buffer usage if `log_analyze` / `log_buffers` are on — which is
invaluable for intermittent slowness caused by parameter values, stale statistics or plan flips. It pairs naturally with
pg_stat_statements: one tells you *which* queries are slow, auto_explain tells you *why*.

## How it's installed

Full procedure: [Install](install.md).

It's a contrib module — it ships in the PostgreSQL **contrib** package (`postgresql-contrib` on most distros; already included in the `postgresql-<ver>` package on Debian/Ubuntu and in the official Docker image), so there's nothing extra to download.
It is a **loadable module only** — there is no `CREATE EXTENSION`. Load it cluster-wide via `shared_preload_libraries`
(restart), for new sessions via `session_preload_libraries`, or ad hoc with `LOAD 'auto_explain';`, then set the
`auto_explain.*` parameters. On RDS / Aurora add it to `shared_preload_libraries` in the parameter group.

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
