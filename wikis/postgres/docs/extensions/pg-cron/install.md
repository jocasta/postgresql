# pg_cron: Install

```ini
# postgresql.conf (restart required)
shared_preload_libraries = 'pg_cron'
cron.database_name = 'postgres'     # the ONE database where the cron schema lives
cron.timezone = 'UTC'               # default GMT
# cron.use_background_workers = on  # run jobs as bgworkers instead of libpq connections
```

```sql
-- in the database named by cron.database_name
CREATE EXTENSION IF NOT EXISTS pg_cron;
GRANT USAGE ON SCHEMA cron TO some_role;   -- optional: let non-superusers schedule
```
