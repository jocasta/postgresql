# Connections

## Postgres Active Connections

``` sql title="postgres_active_connections.sql"
SELECT
    pid,
    usename,
    state,
    client_addr,
    application_name,
    CURRENT_TIMESTAMP - state_change time_in_idle,
    rank() OVER (PARTITION BY client_addr ORDER BY backend_start DESC) AS rank
FROM
    pg_stat_activity
WHERE
-- Exclude the thread owned connection (ie no auto-kill)
pid <> pg_backend_pid()
    AND
    -- Exclude known applications connections
    application_name !~ '(?:pgAdmin.+)'
    AND
    -- Include connections to the same database the thread is connected to
    datname = current_database()
    AND
    -- Include inactive connections only
    state NOT IN ('idle', 'disabled');
```

## Postgres Idle Connection Times

``` sql title="postgres_idle_connection_times.sql"
SELECT
    pid,usename,client_addr,current_timestamp - state_change time_in_idle,
    rank() over (partition by client_addr order by backend_start DESC) as rank
FROM
    pg_stat_activity
WHERE
    -- Exclude the thread owned connection (ie no auto-kill)
    pid <> pg_backend_pid( )
AND
    -- Exclude known applications connections
    application_name !~ '(?:psql)|(?:pgAdmin.+)'
AND
    -- Include connections to the same database the thread is connected to
    datname = current_database()
AND
    -- Include inactive connections only
    state in ('idle', 'idle in transaction', 'idle in transaction (aborted)', 'disabled')
AND
    -- Include old connections (found with the state_change field)
    current_timestamp - state_change > interval '5 minutes';
```
