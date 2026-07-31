#!/usr/bin/env bash
# bring grafana up

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

if [ "${GF_SECURITY_ADMIN_PASSWORD:-changeme}" = "changeme" ]; then
  echo "GF_SECURITY_ADMIN_PASSWORD is still changeme"
  echo "set a real password in .env before first start"
  exit 1
fi

mkdir -p "${DATA_DIR:-./data}"

COMPOSE_CMD="${COMPOSE_CMD:-}"
if [ -z "${COMPOSE_CMD}" ]; then
  if command -v nerdctl >/dev/null 2>&1; then
    COMPOSE_CMD="nerdctl compose"
  else
    COMPOSE_CMD="docker compose"
  fi
fi

echo "starting grafana"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "ui: http://${GF_SERVER_HTTP_ADDR:-127.0.0.1}:${GF_SERVER_HTTP_PORT:-3000}"
echo "bring up prometheus/ and loki/ separately if you have not already"
