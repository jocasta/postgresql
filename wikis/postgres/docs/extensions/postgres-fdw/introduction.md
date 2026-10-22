# postgres_fdw: Introduction

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** No
- **Docs:** <https://www.postgresql.org/docs/current/postgres-fdw.html>

## What it does

postgres_fdw is a foreign data wrapper for querying tables in **another PostgreSQL server** as if they were local.
You define a foreign server and user mapping, then create foreign tables (individually or via `IMPORT FOREIGN SCHEMA`);
`SELECT` / `INSERT` / `UPDATE` / `DELETE` against them are sent to the remote side, with `WHERE` clauses, joins, sorts and
aggregates **pushed down** where possible. Common uses are cross-database reporting, gradual migrations, and archiving
old data to a separate server while keeping it queryable.

## How it's installed

Full procedure: [Install](install.md).

It's a contrib module — it ships in the PostgreSQL **contrib** package (`postgresql-contrib` on most distros; already included in the `postgresql-<ver>` package on Debian/Ubuntu and in the official Docker image), so there's nothing extra to download.
No preload or restart — run `CREATE EXTENSION postgres_fdw;` in the **local** database (nothing is needed on the remote
server other than a login role and network access), then create the server, user mapping and foreign tables as shown below.

---

## Useful options

| Option | Level | Notes |
|---|---|---|
| `fetch_size` | server / table | Rows per fetch (default 100 — usually too low) |
| `batch_size` | server / table | Rows per remote `INSERT` (PG14+) |
| `use_remote_estimate` | server / table | Ask remote for row estimates → better plans |
| `async_capable` | server / table | Parallel scans of multiple foreign partitions (PG14+) |
| `extensions` | server | Allow pushdown of functions/operators from listed extensions |
| `updatable` | server / table | Allow `INSERT/UPDATE/DELETE` (default true) |
| `keep_connections` | server | Cache connections per session (PG14+) |

---

## Checking pushdown

```sql
EXPLAIN (VERBOSE)
SELECT sale_date, sum(total)
FROM reporting.daily_sales
WHERE sale_date >= '2026-01-01'
GROUP BY sale_date;
```

Look for `Remote SQL:` in the output — the `WHERE`, `GROUP BY`, joins and `ORDER BY` should appear there. If not, the work is happening locally after pulling all rows.

---

## Connection management

```sql
SELECT * FROM postgres_fdw_get_connections();     -- open connections in this session
SELECT postgres_fdw_disconnect('reporting_srv');
SELECT postgres_fdw_disconnect_all();
```

---

## Gotchas

- Non-superusers must supply a password in the user mapping (or set `password_required 'false'` as superuser).
- Joins between foreign and local tables can pull the whole foreign table — check `EXPLAIN VERBOSE`.
- Remote transactions use `REPEATABLE READ` (or `SERIALIZABLE`) isolation regardless of the local level.
- Handy for migrations, cross-database reporting and partitioning with foreign partitions (basic sharding).
