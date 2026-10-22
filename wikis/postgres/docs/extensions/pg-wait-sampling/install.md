# pg_wait_sampling: Install

```ini
# postgresql.conf (restart required)
shared_preload_libraries = 'pg_stat_statements,pg_wait_sampling'
```

```sql
CREATE EXTENSION IF NOT EXISTS pg_wait_sampling;
```

!!! note
    Not every managed provider supports it — check the provider's extension list (it is not available on standard Amazon RDS; use Performance Insights / Database Insights there).
