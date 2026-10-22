#!/usr/bin/env bash
set -euo pipefail

###############################################################################
## Load environment
###############################################################################
ENV_FILE=".postgres.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found."
  exit 1
fi

set -o allexport
source "$ENV_FILE"
set +o allexport

###############################################################################
## Validate required variables
###############################################################################
REQUIRED_VARS=(
  PG_VERSION
  CONTAINER_NAME
  HOST_PORT
  DATA_VOLUME
  DB_USER
  DB_PASSWORD
  DB_NAME
)

for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: Environment variable '$var' is not set."
    exit 1
  fi
done

###############################################################################
## Derived values
###############################################################################
IMAGE="local-postgres-timescaledb:${PG_VERSION}"
CONF_FILE="./postgresql.conf"
LOGS_DIR="./logs"

CONF_IN_CONTAINER="/etc/postgresql/postgresql.conf"
LOGS_IN_CONTAINER="/var/log/postgresql"
DATA_IN_CONTAINER="/var/lib/postgresql"

# Second database (telegraf metrics) - migrated separately with flyway_metrics.conf
METRICS_DB_NAME="metrics"

###############################################################################
## Prep filesystem
###############################################################################
echo "[INFO] Ensuring logs directory exists..."
mkdir -p "$LOGS_DIR"
chmod -R 0777 "$LOGS_DIR" 2>/dev/null || true

if [[ ! -f "$CONF_FILE" ]]; then
  echo "ERROR: $CONF_FILE not found."
  exit 1
fi

###############################################################################
## Build custom image (timescaledb included)
###############################################################################
echo "[INFO] Building Postgres image with timescaledb..."
docker build \
  --build-arg PG_VERSION="$PG_VERSION" \
  -t "$IMAGE" .

###############################################################################
## Remove existing container if image changed
###############################################################################
if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  CURRENT_IMAGE="$(docker inspect -f '{{.Config.Image}}' "$CONTAINER_NAME")"
  if [[ "$CURRENT_IMAGE" != "$IMAGE" ]]; then
    echo "[INFO] Existing container uses $CURRENT_IMAGE, recreating..."
    docker rm -f "$CONTAINER_NAME" >/dev/null
  else
    echo "[INFO] Container exists and image matches; restarting..."
    docker restart "$CONTAINER_NAME" >/dev/null
  fi
fi

###############################################################################
## Start container
###############################################################################
if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "[INFO] Starting container '$CONTAINER_NAME'..."

  docker run -d \
    --name "$CONTAINER_NAME" \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$DB_PASSWORD" \
    -e POSTGRES_DB="$DB_NAME" \
    -p "${HOST_PORT}:5432" \
    -v "${DATA_VOLUME}:${DATA_IN_CONTAINER}" \
    -v "$(pwd)/${LOGS_DIR}:${LOGS_IN_CONTAINER}:Z" \
    -v "$(pwd)/${CONF_FILE}:${CONF_IN_CONTAINER}:ro" \
    "$IMAGE" \
    postgres -c "config_file=${CONF_IN_CONTAINER}" >/dev/null

  echo "[INFO] Container started."
fi

###############################################################################
## Create monitoring users (unchanged behavior)
###############################################################################
# Check over TCP: the entrypoint's temporary init server only listens on the
# unix socket, so this won't succeed until the real server is up.
echo "[INFO] Waiting for Postgres to accept connections..."
until docker exec "$CONTAINER_NAME" pg_isready -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; do
  sleep 1
done

echo "[INFO] Ensuring monitoring users exist..."
docker exec -i "$CONTAINER_NAME" \
  psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mike_migrations') THEN
    CREATE ROLE mike_migrations LOGIN SUPERUSER PASSWORD 'jocasta';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mike') THEN
    CREATE ROLE mike LOGIN PASSWORD 'jocasta';
  END IF;

  -- telegraf outputs.postgresql writer (owns the tables it auto-creates)
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'telegraf') THEN
    CREATE ROLE telegraf LOGIN PASSWORD 'telegraf';
  END IF;
END$$;
SQLadd 

###############################################################################
## Create the metrics database (CREATE DATABASE can't run inside flyway)
###############################################################################
METRICS_DB_EXISTS="$(docker exec "$CONTAINER_NAME" psql -tA -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" \
  -c "SELECT 1 FROM pg_database WHERE datname = '${METRICS_DB_NAME}'")"
if [[ -z "$METRICS_DB_EXISTS" ]]; then
  echo "[INFO] Creating database '${METRICS_DB_NAME}'..."
  docker exec "$CONTAINER_NAME" psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" \
    -c "CREATE DATABASE ${METRICS_DB_NAME} OWNER mike_migrations" >/dev/null
else
  echo "[INFO] Database '${METRICS_DB_NAME}' exists."
fi

###############################################################################
## TimescaleDB status (extension is created by flyway, not here)
###############################################################################
PRELOAD="$(docker exec "$CONTAINER_NAME" psql -tA -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" \
  -c "SHOW shared_preload_libraries")"
if [[ "$PRELOAD" != *timescaledb* ]]; then
  echo "ERROR: timescaledb is not in shared_preload_libraries ($PRELOAD)."
  exit 1
fi

TSDB_AVAILABLE="$(docker exec "$CONTAINER_NAME" psql -tA -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" \
  -c "SELECT default_version FROM pg_available_extensions WHERE name = 'timescaledb'")"
echo "[INFO] timescaledb preloaded: yes (available version ${TSDB_AVAILABLE})"

for db in "$DB_NAME" "$METRICS_DB_NAME"; do
  TSDB_INSTALLED="$(docker exec "$CONTAINER_NAME" psql -tA -h 127.0.0.1 -U "$DB_USER" -d "$db" \
    -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb'")"
  if [[ -n "$TSDB_INSTALLED" ]]; then
    echo "[INFO] timescaledb extension: created in '${db}' (version ${TSDB_INSTALLED})"
  else
    echo "[INFO] timescaledb extension: NOT created yet in '${db}' - waiting for 'flyway migrate'"
  fi
done

echo
echo "Connect:"
echo "  psql -h localhost -p ${HOST_PORT} -U ${DB_USER} -d ${DB_NAME}"
echo "  psql -h localhost -p ${HOST_PORT} -U ${DB_USER} -d ${METRICS_DB_NAME}"
echo
echo "Now Run flyway to setup your dev env:"
echo
echo "  $ flyway migrate        # V1 creates the timescaledb extension"
echo "  $ flyway info"
echo "  $ flyway -configFiles=flyway_metrics.conf migrate   # metrics DB: timescaledb + telegraf schema"
echo "  $ flyway -configFiles=flyway_metrics.conf info"
echo
echo "Tail logs:"
echo "  docker logs -f ${CONTAINER_NAME}"
echo