# Connection Pooling

## pgBouncer

pgBouncer is a lightweight connection pooler for PostgreSQL.

- **Session pooling** — one server connection per client session (most compatible)
- **Transaction pooling** — server connection held only during a transaction (most efficient)
- **Statement pooling** — server connection released after each statement

### Key Configuration Parameters

| Parameter | Description |
|---|---|
| `pool_mode` | `session`, `transaction`, or `statement` |
| `max_client_conn` | Max total client connections |
| `default_pool_size` | Server connections per user/database pair |
| `reserve_pool_size` | Extra connections allowed under load |
| `server_idle_timeout` | Close idle server connections after N seconds |
