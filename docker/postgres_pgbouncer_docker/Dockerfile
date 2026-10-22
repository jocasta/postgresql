
ARG PG_VERSION
FROM postgres:${PG_VERSION}

# Install pg_cron and pgbouncer
RUN apt-get update \
 && apt-get install -y postgresql-${PG_MAJOR}-cron pgbouncer \
 && rm -rf /var/lib/apt/lists/*
