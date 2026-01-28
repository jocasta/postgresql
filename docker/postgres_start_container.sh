#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Load environment
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
# Validate required variables
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
# Derived values (single source of truth = PG_VERSION)
###############################################################################
PG_MAJOR="${PG_VERSION%%.*}"                 # e.g. 18.1 -> 18
BASE_IMAGE="postgres:${PG_VERSION}"          # e.g. postgres:18.1
CUSTOM_IMAGE="my-postgres:${PG_VERSION}"     # e.g. my-postgres:18.1

CONF_FILE="./postgresql.conf"
LOGS_DIR="./logs"

CONF_IN_CONTAINER="/etc/postgresql/postgresql.conf"
LOGS_IN_CONTAINER="/var/log/postgresql"

###############################################################################
# Prep File System
###############################################################################
echo "[$(date '+%H:%M:%S')] Ensuring logs directory exists..."
mkdir -p "$LOGS_DIR"

# Dev-only: ensure logs are writable and deletable without sudo
chmod -R 0777 "$LOGS_DIR" 2>/dev/null || true

# Fail fast if config missing
if [[ ! -f "$CONF_FILE" ]]; then
  echo "ERROR: $CONF_FILE not found."
  echo "Create it alongside this script."
  exit 1
fi

###############################################################################
# Build custom image (pg_cron + pg_partman)
###############################################################################
echo "[$(date '+%H:%M:%S')] Building image '${CUSTOM_IMAGE}' from '${BASE_IMAGE}' (PG_MAJOR=${PG_MAJOR})..."
docker build \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --build-arg PG_MAJOR="${PG_MAJOR}" \
  -t "${CUSTOM_IMAGE}" \
  .

###############################################################################
# Existing container handling
###############################################################################
if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "[$(date '+%H:%M:%S')] Container '$CONTAINER_NAME' already exists."

  CURRENT_IMAGE="$(docker inspect -f '{{.Config.Image}}' "$CONTAINER_NAME")"
  if [[ "$CURRENT_IMAGE" != "$CUSTOM_IMAGE" ]]; then
    echo "[$(date '+%H:%M:%S')] Existing container image is '$CURRENT_IMAGE' but you want '$CUSTOM_IMAGE'. Recreating..."
    docker rm -f "$CONTAINER_NAME" >/dev/null
  else
    echo "[$(date '+%H:%M:%S')] Image tag matches ($CUSTOM_IMAGE). Restarting to apply config..."
    docker restart "$CONTAINER_NAME" >/dev/null
    echo "[$(date '+%H:%M:%S')] Done."
    docker ps --filter "name=^/${CONTAINER_NAME}$"
    exit 0
  fi
fi

###############################################################################
# Create container
###############################################################################
echo "[$(date '+%H:%M:%S')] Creating container '$CONTAINER_NAME' with image '$CUSTOM_IMAGE'..."

# NOTE: Postgres 18+ expects data mounted at /var/lib/postgresql (NOT /var/lib/postgresql/data)
# NOTE: ':Z' on the logs bind mount helps on SELinux enforcing systems (Fedora/RHEL)
docker run -d \
  --name "$CONTAINER_NAME" \
  -e POSTGRES_USER="$DB_USER" \
  -e POSTGRES_PASSWORD="$DB_PASSWORD" \
  -e POSTGRES_DB="$DB_NAME" \
  -p "${HOST_PORT}:5432" \
  -v "${DATA_VOLUME}:/var/lib/postgresql" \
  -v "$(pwd)/${LOGS_DIR#./}:${LOGS_IN_CONTAINER}:Z" \
  -v "$(pwd)/${CONF_FILE#./}:${CONF_IN_CONTAINER}:ro" \
  "$CUSTOM_IMAGE" \
  postgres -c "config_file=${CONF_IN_CONTAINER}" >/dev/null

echo "[$(date '+%H:%M:%S')] Started."
docker ps --filter "name=^/${CONTAINER_NAME}$"

echo
echo "Connect:"
echo "  psql -h localhost -p ${HOST_PORT} -U ${DB_USER} -d ${DB_NAME}"
echo
echo "Tail docker logs:"
echo "  docker logs -f ${CONTAINER_NAME}"
echo
echo "List log files:"
echo "  ls -lah ${LOGS_DIR}"

echo
echo "Enable extensions (one-time per database):"
echo "  psql -h localhost -p ${HOST_PORT} -U ${DB_USER} -d postgres -c \"CREATE EXTENSION IF NOT EXISTS pg_cron;\""
echo "  psql -h localhost -p ${HOST_PORT} -U ${DB_USER} -d ${DB_NAME} -c \"CREATE EXTENSION IF NOT EXISTS pg_partman;\""
