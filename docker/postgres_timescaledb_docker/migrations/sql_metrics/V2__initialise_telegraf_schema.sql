
-- TELEGRAF CREATES ITS OWN TABLES (create_templates in telegraf.conf), SO THE
-- SCHEMA IS OWNED BY telegraf. OWNING THE TABLES IS ALSO WHAT LETS telegraf
-- RUN create_hypertable / SET (timescaledb.compress) / add_*_policy ON THEM.
-- (the telegraf role is created by postgres_start_container.sh)
CREATE SCHEMA IF NOT EXISTS telegraf AUTHORIZATION telegraf ;

-- READ ACCESS FOR mike ON EVERYTHING telegraf CREATES
GRANT USAGE ON SCHEMA telegraf TO mike;
ALTER DEFAULT PRIVILEGES
FOR ROLE telegraf
IN SCHEMA telegraf
GRANT SELECT
ON TABLES
TO mike;
