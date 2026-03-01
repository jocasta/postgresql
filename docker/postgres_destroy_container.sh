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

LOGS_DIR="./logs"

# Repos we consider "postgres related" for this dev setup
REPOS_REGEX='^(postgres|test-postgres|my-postgres)(:|$)'

echo "🔥 Destroying postgres-related dev resources (scoped; not nuking all Docker)..."

###############################################################################
# 1) Find containers to remove (your named one + any using postgres repos)
###############################################################################
CONTAINER_IDS_TO_REMOVE="$(
  docker ps -a --format '{{.ID}} {{.Names}} {{.Image}}' \
  | awk -v name="$CONTAINER_NAME" -v re="$REPOS_REGEX" '
      ($2 == name) || ($3 ~ re) { print $1 }
    ' \
  | sort -u
)"

if [[ -n "${CONTAINER_IDS_TO_REMOVE}" ]]; then
  echo "Removing containers:"
  docker ps -a --format '  {{.Names}}  ({{.Image}})' \
    | awk -v name="$CONTAINER_NAME" -v re="$REPOS_REGEX" '
        ($1 == name) || ($2 ~ re) { print }
      ' || true

  # Capture any named volumes attached to these containers (optional extra safety)
  VOLUMES_FROM_CONTAINERS="$(
    docker inspect ${CONTAINER_IDS_TO_REMOVE} \
      --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{"\n"}}{{end}}{{end}}' \
    | sort -u
  )"

  docker rm -f ${CONTAINER_IDS_TO_REMOVE} >/dev/null || true
else
  echo "No postgres-related containers found."
  VOLUMES_FROM_CONTAINERS=""
fi

###############################################################################
# 2) Remove volumes (explicit + any discovered from container mounts)
###############################################################################
VOLUMES_TO_REMOVE="$(printf "%s\n%s\n" "${DATA_VOLUME:-}" "${VOLUMES_FROM_CONTAINERS:-}" | sed '/^$/d' | sort -u)"

if [[ -n "${VOLUMES_TO_REMOVE}" ]]; then
  echo "Removing volumes:"
  echo "${VOLUMES_TO_REMOVE}" | sed 's/^/  /'
  # Only remove volumes that actually exist
  while read -r v; do
    if docker volume inspect "$v" >/dev/null 2>&1; then
      docker volume rm "$v" >/dev/null || true
    fi
  done <<< "${VOLUMES_TO_REMOVE}"
else
  echo "No postgres-related volumes found."
fi

###############################################################################
# 3) Remove logs folder
###############################################################################
if [[ -d "$LOGS_DIR" ]]; then
  echo "Removing logs folder $LOGS_DIR..."
  chmod -R 0777 "$LOGS_DIR" 2>/dev/null || true
  rm -rf "$LOGS_DIR"
fi

###############################################################################
# 4) Remove images (postgres + your custom images)
###############################################################################
IMAGES_TO_REMOVE="$(
  docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' \
  | awk -v re="$REPOS_REGEX" '$1 ~ re { print $1 }' \
  | sort -u
)"

if [[ -n "${IMAGES_TO_REMOVE}" ]]; then
  echo "Removing images:"
  echo "${IMAGES_TO_REMOVE}" | sed 's/^/  /'
  # Force remove to ensure tags are gone (containers already removed above)
  while read -r img; do
    docker rmi -f "$img" >/dev/null || true
  done <<< "${IMAGES_TO_REMOVE}"
else
  echo "No postgres-related images found."
fi

echo "✅ Clean slate complete (postgres-related only)."