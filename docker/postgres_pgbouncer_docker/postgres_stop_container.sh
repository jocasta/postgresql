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

for name in "$PGBOUNCER_CONTAINER_NAME" "$CONTAINER_NAME"; do
  if docker inspect "$name" >/dev/null 2>&1; then
    echo "Stopping $name..."
    docker stop "$name" >/dev/null || true
    echo "Stopped."
  else
    echo "Container '$name' does not exist."
  fi
done
