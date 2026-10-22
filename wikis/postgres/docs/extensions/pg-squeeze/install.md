# pg_squeeze: Install

```ini
# postgresql.conf (restart required)
wal_level = logical
max_replication_slots = 10                   # pg_squeeze uses one slot per running squeeze
shared_preload_libraries = 'pg_squeeze'

# optional: start the scheduler workers automatically
squeeze.worker_autostart = 'appdb'           # space-separated list of databases
squeeze.worker_role = 'postgres'
```

```sql
CREATE EXTENSION IF NOT EXISTS pg_squeeze;   -- objects live in schema "squeeze"
```
