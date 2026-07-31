#!/usr/bin/env bash
# bring excalidraw up

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env - copy .env.example to .env and edit"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

COMPOSE_CMD="${COMPOSE_CMD:-}"
if [ -z "${COMPOSE_CMD}" ]; then
  if command -v nerdctl >/dev/null 2>&1; then
    COMPOSE_CMD="nerdctl compose"
  else
    COMPOSE_CMD="docker compose"
  fi
fi

PROFILE_ARGS=()
if [ "${ENABLE_BASIC_AUTH:-n}" = "y" ] || [ "${ENABLE_BASIC_AUTH:-n}" = "Y" ]; then
  if [ ! -f secrets/htpasswd ]; then
    echo "ENABLE_BASIC_AUTH is set but secrets/htpasswd is missing"
    echo "run ./scripts/htpasswd.sh first"
    exit 1
  fi
  PROFILE_ARGS+=(--profile auth)
fi

echo "starting excalidraw"
${COMPOSE_CMD} "${PROFILE_ARGS[@]}" up -d "$@"
echo "up done"
echo "ui:   http://${HOST_BIND:-127.0.0.1}:${UI_HOST_PORT:-5000}"
echo "room: http://${HOST_BIND:-127.0.0.1}:${ROOM_HOST_PORT:-5001}"
if [ "${ENABLE_BASIC_AUTH:-n}" = "y" ] || [ "${ENABLE_BASIC_AUTH:-n}" = "Y" ]; then
  echo "auth: http://${HOST_BIND:-127.0.0.1}:${AUTH_HOST_PORT:-5002}  (use this behind your proxy)"
fi
