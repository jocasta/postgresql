-- timescaledb is preloaded via shared_preload_libraries (postgresql.conf);
-- this creates the extension in the database.
-- WITH SCHEMA public: flyway sets search_path to the 'flyway' schema first,
-- without this the extension functions would land in the flyway schema.
CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public;
