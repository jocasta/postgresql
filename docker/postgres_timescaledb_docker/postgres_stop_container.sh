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

if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "Stopping $CONTAINER_NAME..."
  docker stop "$CONTAINER_NAME" >/dev/null || true
  echo "Stopped."
else
  echo "Container '$CONTAINER_NAME' does not exist."
fi

