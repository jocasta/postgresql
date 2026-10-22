# postgres_pgbouncer_docker

Local Postgres in Docker with [PgBouncer](https://www.pgbouncer.org/) in front of it.

```
psql / app ──► localhost:6432 ──► pgbouncer container ──► postgres container:5432
psql / app ──► localhost:5432 ─────────────────────────► postgres container:5432
```

Both containers use the same locally built image (`postgres:<PG_VERSION>` + `pg_cron` + `pgbouncer`)
and share a private Docker network, where Postgres is reachable as `postgres`.

---

## Usage

```bash
./postgres_start_container.sh     # build image, start postgres + pgbouncer
./postgres_stop_container.sh      # stop both (data volume kept)
./postgres_destroy_container.sh   # remove containers, network, volume, logs, image
```

Connect:

```bash
psql -h localhost -p 5432 -U mike -d test   # direct
psql -h localhost -p 6432 -U mike -d test   # via pgbouncer
```

Admin console (`admin_users` in `pgbouncer.ini`):

```bash
psql -h localhost -p 6432 -U mike -d pgbouncer -c 'SHOW POOLS;'
psql -h localhost -p 6432 -U mike -d pgbouncer -c 'SHOW STATS;'
psql -h localhost -p 6432 -U mike -d pgbouncer -c 'RELOAD;'   # after editing pgbouncer.ini
```

> Uses the same host port `5432` as `postgres_flyway_docker`. Stop that one first, or change `HOST_PORT`.

---

## Files

| File | Purpose |
|---|---|
| `.postgres.env` | Container names, ports, volume, credentials |
| `Dockerfile` | Adds `pg_cron` and `pgbouncer` to the official image |
| `postgresql.conf` | Postgres config (logs to `./logs`) |
| `pgbouncer/pgbouncer.ini` | PgBouncer config (pool mode, sizes, admin users) |
| `pgbouncer/userlist.txt` | **Generated** on start from `DB_USER`/`DB_PASSWORD`. Git-ignored |

---

## PgBouncer notes

- **Pool mode** is `transaction`. Session state (`SET`, advisory locks, `LISTEN`, temp tables)
  does not survive between transactions. Switch to `pool_mode = session` in `pgbouncer.ini`
  if a client needs it (e.g. running Flyway through pgbouncer).
- **Adding users**: create the role in Postgres, then add `"user" "password"` to the heredoc that
  generates `userlist.txt` in `postgres_start_container.sh`, and re-run it.
- **Changing `DB_USER`**: also update `admin_users` / `stats_users` in `pgbouncer.ini`.
- PgBouncer is stateless, so the start script always recreates its container to pick up config changes.

---

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `PG_VERSION` | `18.6` | Postgres version |
| `CONTAINER_NAME` | `postgres18_6_pgb` | Postgres container name (network is `<name>_net`) |
| `HOST_PORT` | `5432` | Postgres port on localhost |
| `DATA_VOLUME` | `pg18_pgb_data` | Named Docker volume for data |
| `DB_USER` | `mike` | Superuser created on init |
| `DB_PASSWORD` | `test` | Superuser password |
| `DB_NAME` | `test` | Database created on init |
| `PGBOUNCER_CONTAINER_NAME` | `pgbouncer18_6` | PgBouncer container name |
| `PGBOUNCER_HOST_PORT` | `6432` | PgBouncer port on localhost |
