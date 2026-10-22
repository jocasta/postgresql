# pg_repack: Install

```sql
CREATE EXTENSION IF NOT EXISTS pg_repack;
SELECT extversion FROM pg_extension WHERE extname = 'pg_repack';
```

Install the matching client (`pg_repack` binary) — **client and extension versions must match exactly**.

```bash
# Debian/Ubuntu (PGDG repo)
sudo apt install postgresql-17-repack
pg_repack --version
```
