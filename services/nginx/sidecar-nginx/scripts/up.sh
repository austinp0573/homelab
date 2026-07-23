#!/usr/bin/env bash
# bring sidecar nginx up

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

CONF="${NGINX_CONF:-./config/proxy/nginx.conf}"
if [ ! -f "${CONF}" ]; then
  echo "NGINX_CONF not found: ${CONF}"
  exit 1
fi

echo "starting sidecar-nginx (${CONF})"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "http://${HOST_BIND:-127.0.0.1}:${HOST_PORT:-8080}"
