# pg_lake: Introduction

- **Type:** third-party (Snowflake Labs) — build from source / Docker
- **Repo:** <https://github.com/Snowflake-Labs/pg_lake>
- **Talk:** <https://www.youtube.com/watch?v=ReOYXSsE7r8>

## What it does

pg_lake (Snowflake Labs) integrates PostgreSQL with the **data lake**. It lets you create and modify **Apache Iceberg**
tables transactionally from Postgres, query and import Parquet, CSV, JSON and Iceberg files sitting in object storage
(S3, GCS, …) as foreign tables, `COPY` query results back out to the lake, and join heap tables, Iceberg tables and raw files
in a single SQL statement.

Under the hood, Postgres handles parsing, planning and transactions, while heavy scans are delegated to **pgduck_server** — a
separate process that embeds **DuckDB** and speaks the Postgres wire protocol (Unix socket, port 5332 by default).
The functionality is split into modules: `pg_lake_iceberg`, `pg_lake_table` (FDW for lake files), `pg_lake_copy`,
`pg_lake_engine`, and supporting `pg_extension_base` / `pg_map`.

## How it's installed

Not packaged by PGDG or managed providers — use the Docker setup in the repo or build from source, run
`CREATE EXTENSION pg_lake CASCADE;`, and run `pgduck_server` alongside Postgres. Full procedure: [Install](install.md).
