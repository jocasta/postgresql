# postgres_fdw

Foreign data wrapper for querying tables in **another PostgreSQL server** as if they were local.

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** No
- **Docs:** <https://www.postgresql.org/docs/current/postgres-fdw.html>

---

## Setup

```sql
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- 1. The remote server
CREATE SERVER reporting_srv
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'reporting.internal', port '5432', dbname 'reporting',
             fetch_size '10000', use_remote_estimate 'true');

-- 2. Credentials: local role → remote role
CREATE USER MAPPING FOR app_user
    SERVER reporting_srv
    OPTIONS (user 'readonly', password 'secret');

-- 3. Foreign tables — import a whole schema…
CREATE SCHEMA IF NOT EXISTS reporting;
IMPORT FOREIGN SCHEMA public
    LIMIT TO (daily_sales, customers)
    FROM SERVER reporting_srv
    INTO reporting;

-- …or define one by hand
CREATE FOREIGN TABLE reporting.daily_sales_manual (
    sale_date date,
    total     numeric
) SERVER reporting_srv OPTIONS (schema_name 'public', table_name 'daily_sales');

SELECT * FROM reporting.daily_sales WHERE sale_date >= current_date - 7;
```

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
