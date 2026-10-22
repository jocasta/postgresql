# pg_stat_statements: Install

```ini
# postgresql.conf (restart required)
shared_preload_libraries = 'pg_stat_statements'
compute_query_id = auto              # PG14+, default
pg_stat_statements.max = 10000       # distinct statements tracked
pg_stat_statements.track = top       # top | all | none
pg_stat_statements.track_utility = on
pg_stat_statements.track_planning = off  # on adds overhead
```

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```
