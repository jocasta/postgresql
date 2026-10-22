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
  PGBOUNCER_CONTAINER_NAME
  PGBOUNCER_HOST_PORT
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
IMAGE="local-postgres-pgbouncer:${PG_VERSION}"
NETWORK="${CONTAINER_NAME}_net"
CONF_FILE="./postgresql.conf"
LOGS_DIR="./logs"
PGBOUNCER_INI="./pgbouncer/pgbouncer.ini"
USERLIST_FILE="./pgbouncer/userlist.txt"

CONF_IN_CONTAINER="/etc/postgresql/postgresql.conf"
LOGS_IN_CONTAINER="/var/log/postgresql"
DATA_IN_CONTAINER="/var/lib/postgresql"
PGBOUNCER_INI_IN_CONTAINER="/etc/pgbouncer/pgbouncer.ini"
USERLIST_IN_CONTAINER="/etc/pgbouncer/userlist.txt"

###############################################################################
## Prep filesystem
###############################################################################
echo "[INFO] Ensuring logs directory exists..."
mkdir -p "$LOGS_DIR"
chmod -R 0777 "$LOGS_DIR" 2>/dev/null || true

for f in "$CONF_FILE" "$PGBOUNCER_INI"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: $f not found."
    exit 1
  fi
done

# pgbouncer authenticates clients against this file. Plain-text passwords let
# it do SCRAM to both the client and the server. Add extra users here.
echo "[INFO] Generating $USERLIST_FILE..."
cat > "$USERLIST_FILE" <<EOF
"${DB_USER}" "${DB_PASSWORD}"
EOF
chmod 0644 "$USERLIST_FILE"

###############################################################################
## Build custom image (pg_cron + pgbouncer included)
###############################################################################
echo "[INFO] Building Postgres image with pg_cron and pgbouncer..."
docker build \
  --build-arg PG_VERSION="$PG_VERSION" \
  -t "$IMAGE" .

###############################################################################
## Network shared by postgres and pgbouncer
###############################################################################
if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "[INFO] Creating network '$NETWORK'..."
  docker network create "$NETWORK" >/dev/null
fi

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
## Start postgres container
###############################################################################
if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "[INFO] Starting container '$CONTAINER_NAME'..."

  docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --network-alias postgres \
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

# Check over TCP: the entrypoint's temporary init server only listens on the
# unix socket, so this won't succeed until the real server is up.
echo "[INFO] Waiting for Postgres to accept connections..."
until docker exec "$CONTAINER_NAME" pg_isready -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; do
  sleep 1
done

###############################################################################
## Start pgbouncer container (stateless, so always recreated to pick up config)
###############################################################################
if docker inspect "$PGBOUNCER_CONTAINER_NAME" >/dev/null 2>&1; then
  docker rm -f "$PGBOUNCER_CONTAINER_NAME" >/dev/null
fi

echo "[INFO] Starting container '$PGBOUNCER_CONTAINER_NAME'..."
docker run -d \
  --name "$PGBOUNCER_CONTAINER_NAME" \
  --network "$NETWORK" \
  --user postgres \
  --entrypoint pgbouncer \
  -p "${PGBOUNCER_HOST_PORT}:6432" \
  -v "$(pwd)/${PGBOUNCER_INI}:${PGBOUNCER_INI_IN_CONTAINER}:ro" \
  -v "$(pwd)/${USERLIST_FILE}:${USERLIST_IN_CONTAINER}:ro" \
  "$IMAGE" \
  "$PGBOUNCER_INI_IN_CONTAINER" >/dev/null

echo "[INFO] Waiting for pgbouncer to accept connections..."
for _ in $(seq 1 30); do
  if docker exec "$PGBOUNCER_CONTAINER_NAME" pg_isready -h 127.0.0.1 -p 6432 -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
    break
  fi
  if [[ "$(docker inspect -f '{{.State.Running}}' "$PGBOUNCER_CONTAINER_NAME")" != "true" ]]; then
    echo "ERROR: pgbouncer exited. Logs:"
    docker logs "$PGBOUNCER_CONTAINER_NAME"
    exit 1
  fi
  sleep 1
done

echo
echo "Connect direct:"
echo "  psql -h localhost -p ${HOST_PORT} -U ${DB_USER} -d ${DB_NAME}"
echo
echo "Connect via pgbouncer:"
echo "  psql -h localhost -p ${PGBOUNCER_HOST_PORT} -U ${DB_USER} -d ${DB_NAME}"
echo
echo "pgbouncer admin console:"
echo "  psql -h localhost -p ${PGBOUNCER_HOST_PORT} -U ${DB_USER} -d pgbouncer -c 'SHOW POOLS;'"
echo
echo "Tail logs:"
echo "  docker logs -f ${CONTAINER_NAME}"
echo "  docker logs -f ${PGBOUNCER_CONTAINER_NAME}"
echo
