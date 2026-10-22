# pg_lake: Install

## 1. Get the binaries

Not packaged by PGDG or managed providers. Either:

- **Docker** — follow `docker/README.md` in the [pg_lake repo](https://github.com/Snowflake-Labs/pg_lake), or
- **Build from source** — follow `docs/building-from-source.md` in the repo (it also covers a local MinIO setup for S3-compatible storage).

---

## 2. Create the extensions

```sql
CREATE EXTENSION pg_lake CASCADE;   -- pulls in pg_lake_table, pg_lake_engine, pg_lake_iceberg, pg_lake_copy, pg_extension_base
```

---

## 3. Start pgduck_server

Must be running alongside Postgres — it executes the DuckDB side of queries.

```bash
pgduck_server --memory_limit 4GB --cache_dir /var/cache/pgduck   # also: --init_file_path <path>
psql -p 5332 -h /tmp                                              # connect to it directly if needed
```

---

## 4. Configure object storage

Credentials come from the standard AWS / GCP credential chain (e.g. `~/.aws/credentials`) via DuckDB's secrets manager.
Then set where new Iceberg tables are written:

```sql
SET pg_lake_iceberg.default_location_prefix TO 's3://my-bucket/pglake';
```
