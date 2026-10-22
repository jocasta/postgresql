-- timescaledb is preloaded via shared_preload_libraries (postgresql.conf);
-- this creates the extension in the metrics database.
-- WITH SCHEMA public: flyway sets search_path to the 'flyway' schema first,
-- without this the extension functions would land in the flyway schema.
-- telegraf's create_templates call create_hypertable() etc. unqualified, so
-- they must be in public (on telegraf's default search_path).
CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public;
