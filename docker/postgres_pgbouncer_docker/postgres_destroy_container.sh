#!/usr/bin/env bash

set -euo pipefail

ENV_FILE=".postgres.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found."
  exit 1
fi

set -o allexport
source "$ENV_FILE"
set +o allexport

IMAGE="local-postgres-pgbouncer:${PG_VERSION}"
NETWORK="${CONTAINER_NAME}_net"
LOGS_DIR="./logs"
USERLIST_FILE="./pgbouncer/userlist.txt"

for name in "$PGBOUNCER_CONTAINER_NAME" "$CONTAINER_NAME"; do
  if docker inspect "$name" >/dev/null 2>&1; then
    echo "Removing container $name..."
    docker rm -f "$name" >/dev/null || true
  fi
done

if docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "Removing network $NETWORK..."
  docker network rm "$NETWORK" >/dev/null || true
fi

if docker volume inspect "$DATA_VOLUME" >/dev/null 2>&1; then
  echo "Removing data volume $DATA_VOLUME..."
  docker volume rm "$DATA_VOLUME" >/dev/null || true
fi

if [[ -d "$LOGS_DIR" ]]; then
  echo "Removing logs folder $LOGS_DIR..."
  chmod -R 0777 "$LOGS_DIR" 2>/dev/null || true
  rm -rf "$LOGS_DIR"
fi

if [[ -f "$USERLIST_FILE" ]]; then
  echo "Removing $USERLIST_FILE..."
  rm -f "$USERLIST_FILE"
fi

if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Removing image $IMAGE..."
  docker rmi "$IMAGE" >/dev/null 2>&1 || true
fi

echo "Destroyed dev environment."
