# pg_statviz: Install

## 1. Extension (on the server)

```bash
# Debian / Ubuntu (PGDG apt repo)
sudo apt install postgresql-<ver>-statviz

# RHEL / Fedora (PGDG yum repo)
sudo dnf install pg_statviz_extension-<ver>

# or PGXN
pgxn install pg_statviz

# or from source
git clone https://github.com/vyruss/pg_statviz.git
cd pg_statviz
sudo make install
```

No preload or restart needed:

```sql
\c mydatabase
CREATE EXTENSION pg_statviz;   -- objects live in schema "pgstatviz"
```

Superusers or members of `pg_monitor` can use it.

---

## 2. Utility (on any client, Python 3.11+)

```bash
pip install pg_statviz
pip install 'pg_statviz[ai]'    # optional: LLM commentary for `pg_statviz analyze --ai`
```

---

## 3. Schedule snapshots

```sql
SELECT pgstatviz.snapshot();   -- take one now

-- every 15 minutes with pg_cron
SELECT cron.schedule('statviz-snapshot', '*/15 * * * *', 'SELECT pgstatviz.snapshot()');
```

```bash
# or with system cron
*/15 * * * * psql -d mydatabase -c "SELECT pgstatviz.snapshot()" >/dev/null 2>&1
```
