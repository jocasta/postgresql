
# Default only satisfies the linter - postgres_start_container.sh always
# passes --build-arg PG_VERSION from .postgres.env
ARG PG_VERSION=latest
FROM postgres:${PG_VERSION}

# Install TimescaleDB from the Timescale apt repo (packagecloud).
# The binaries are installed and preloaded via postgresql.conf, but the
# extension itself is NOT created here - that is done by `flyway migrate`.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
    | gpg --dearmor -o /etc/apt/keyrings/timescaledb.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian/ $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
    > /etc/apt/sources.list.d/timescaledb.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends timescaledb-2-postgresql-${PG_MAJOR} \
 && apt-get purge -y --auto-remove curl gnupg \
 && rm -rf /var/lib/apt/lists/*
