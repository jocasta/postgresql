# postgres_fdw: Install

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
