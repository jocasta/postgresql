# auto_explain: Install

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
