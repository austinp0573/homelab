#!/usr/bin/env bash
# bring loki + alloy up

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

mkdir -p "${DATA_DIR:-./data}" "${ALLOY_DATA_DIR:-./alloy-data}"

COMPOSE_CMD="${COMPOSE_CMD:-}"
if [ -z "${COMPOSE_CMD}" ]; then
  if command -v nerdctl >/dev/null 2>&1; then
    COMPOSE_CMD="nerdctl compose"
  else
    COMPOSE_CMD="docker compose"
  fi
fi

echo "starting loki"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "loki: http://${HOST_BIND:-127.0.0.1}:${HOST_PORT:-3100}"
echo "alloy ui: http://${HOST_BIND:-127.0.0.1}:${ALLOY_HOST_PORT:-12345}"
