# pg_repack

Removes table and index bloat **online** — rebuilds the table in the background and swaps it in, holding an `ACCESS EXCLUSIVE` lock only briefly at the start and end (unlike `VACUUM FULL` / `CLUSTER`, which lock for the whole rewrite).

- **Type:** third-party — extension **plus** a client binary
- **Preload required:** No
- **Repo:** <https://github.com/reorg/pg_repack>

---

## Install

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

---

## Usage

```bash
# Repack one table (and its indexes)
pg_repack -h myhost -U postgres -d appdb -t public.orders

# Only rebuild the indexes of a table
pg_repack -h myhost -U postgres -d appdb -t public.orders --only-indexes

# A single index
pg_repack -h myhost -U postgres -d appdb -i public.orders_created_at_idx

# Rewrite ordered by a column (online CLUSTER)
pg_repack -d appdb -t public.orders -o created_at

# Parallel index builds, and a dry run first
pg_repack -d appdb -t public.orders -j 4 --dry-run

# RDS / Aurora: no real superuser
pg_repack -h mydb.xxxx.rds.amazonaws.com -U postgres -d appdb -t public.orders -k
```

| Flag | Meaning |
|---|---|
| `-t` / `-I` | Table / all inheritance children (or partitions) of a parent |
| `-i` / `-x` | Single index / only indexes of `-t` |
| `-o col` | Order rows by column (online CLUSTER) |
| `-n` | `--no-order` — VACUUM FULL style |
| `-j N` | Parallel index builds |
| `-k` | Skip superuser check (managed services) |
| `-T secs` | `--wait-timeout` before cancelling conflicting queries |
| `-D` | `--no-kill-backend` — give up instead of killing blockers |
| `-N` | `--dry-run` |

---

## Requirements & gotchas

- Table needs a **primary key or a NOT NULL unique index**.
- Needs free disk ≈ **2× the table + indexes** while running.
- Generates a lot of WAL — watch replica lag and replication slots.
- The brief `ACCESS EXCLUSIVE` locks can still queue behind long-running transactions (and block others behind them). Run off-peak; consider `-T` / `-D`.
- DDL on the table during a repack will break it — don't run migrations concurrently.
- If interrupted, clean up leftovers: `DROP EXTENSION pg_repack CASCADE; CREATE EXTENSION pg_repack;`

Measure bloat first with [pgstattuple](../pgstattuple/index.md). Alternative: [pg_squeeze](../pg-squeeze/index.md) (logical-decoding based, no triggers).
