# Dummy Page 1

This is a placeholder page used to test nested navigation.

## Python snippet

``` python title="connect.py"
import psycopg

def fetch_users(conn_string: str) -> list[dict]:
    with psycopg.connect(conn_string) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name, email FROM users WHERE active = %s", (True,))
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]
```

## SQL snippet

``` sql title="active_users.sql"
SELECT
    u.id,
    u.name,
    u.email,
    count(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.active = true
GROUP BY u.id, u.name, u.email
ORDER BY order_count DESC
LIMIT 10;
```
