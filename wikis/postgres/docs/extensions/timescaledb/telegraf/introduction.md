# Telegraf

Telegraf's `outputs.postgresql` plugin creates a table per measurement the first time it sees it.
Its `create_templates` run at that point, so every new measurement automatically becomes a hypertable
with compression and retention — no per-table migrations.

- **Plugin docs:** <https://github.com/influxdata/telegraf/tree/master/plugins/outputs/postgresql>

---

## Telegraf config

```toml
[[outputs.postgresql]]
  connection = "host=localhost port=5432 user=telegraf password=secret dbname=metrics sslmode=disable"
  schema = "telegraf"
  tags_as_foreign_keys = true

  create_templates = [
    '''CREATE TABLE {{ .table }} ({{ .columns }})''',

    '''SELECT create_hypertable(
         {{ .table|quoteLiteral }},
         'time',
         chunk_time_interval => INTERVAL '1 day'
       )''',

    '''ALTER TABLE {{ .table }} SET (
         timescaledb.compress,
         timescaledb.compress_segmentby = 'tag_id'
       )''',

    '''SELECT add_compression_policy(
         {{ .table|quoteLiteral }},
         INTERVAL '7 days'
       )''',

    '''SELECT add_retention_policy(
         {{ .table|quoteLiteral }},
         INTERVAL '90 days'
       )'''
  ]
```

- With `tags_as_foreign_keys = true` each measurement gets a metric hypertable (`telegraf.cpu`, with a
  `tag_id` column) plus a plain tag table (`telegraf.cpu_tag`).
- Tag tables are created from `tag_table_create_templates`, **not** `create_templates`, so they stay
  ordinary tables — which is why `compress_segmentby = 'tag_id'` works.
- New fields are added with `add_column_templates` (`ALTER TABLE ... ADD COLUMN`), which works on
  compressed hypertables for nullable columns.
- `create_hypertable(table, 'time', chunk_time_interval => ...)` is the older, deprecated API; the newer
  form is `create_hypertable({{ .table|quoteLiteral }}, by_range('time', INTERVAL '1 day'))`.

---

## Database setup (migrations)

The database and schema are managed by migrations; the tables are not.

```sql
-- Role (cluster-wide) and database: outside Flyway (CREATE DATABASE can't run in a migration)
CREATE ROLE telegraf LOGIN PASSWORD 'secret';
CREATE DATABASE metrics OWNER mike_migrations;
```

```sql
-- V1: extension in public - the templates call create_hypertable() etc. unqualified,
--     and public is on telegraf's default search_path ("$user", public)
CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public;

-- V2: telegraf owns its schema
CREATE SCHEMA IF NOT EXISTS telegraf AUTHORIZATION telegraf;

GRANT USAGE ON SCHEMA telegraf TO mike;
ALTER DEFAULT PRIVILEGES FOR ROLE telegraf IN SCHEMA telegraf
  GRANT SELECT ON TABLES TO mike;
```

Why `telegraf` owns the schema: it can `CREATE TABLE` there, and as **owner of each table** it can run
`create_hypertable`, set compression and add policies without being a superuser. The policy jobs then run
as `telegraf`.

Anything else in this database (continuous aggregates over Telegraf tables, extra grants) goes in
migrations — but a cagg can only be migrated once Telegraf has created its source table.

---

## Checks

```sql
-- Can telegraf connect, and what is its search_path?
-- psql "host=localhost port=5432 user=telegraf password=secret dbname=metrics"
SELECT current_user, current_setting('search_path');

-- Tables telegraf has created, and which are hypertables
\dt telegraf.*
SELECT hypertable_schema, hypertable_name, compression_enabled
FROM timescaledb_information.hypertables;

-- Policies added by the create_templates
SELECT job_id, application_name, hypertable_name, owner, config
FROM timescaledb_information.jobs
WHERE hypertable_schema = 'telegraf';

-- Query a measurement joined to its tags
SELECT c.time, t.*, c.usage_user
FROM telegraf.cpu c
JOIN telegraf.cpu_tag t USING (tag_id)
ORDER BY c.time DESC LIMIT 20;
```
