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

IMAGE="postgres:${PG_VERSION}"
LOGS_DIR="./logs"

if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "Removing container $CONTAINER_NAME..."
  docker rm -f "$CONTAINER_NAME" >/dev/null || true
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

if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Removing image $IMAGE..."
  docker rmi "$IMAGE" >/dev/null || true
fi

echo "Destroyed dev environment."

