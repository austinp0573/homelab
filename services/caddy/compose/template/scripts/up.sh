#!/usr/bin/env bash
# bring caddy up

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env - copy .env.example to .env and edit"
  exit 1
fi

if [ ! -f Caddyfile ]; then
  echo "missing Caddyfile"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

mkdir -p "${DATA_DIR:-./data}" "${CONFIG_DIR:-./config}"

COMPOSE_CMD="${COMPOSE_CMD:-}"
if [ -z "${COMPOSE_CMD}" ]; then
  if command -v nerdctl >/dev/null 2>&1; then
    COMPOSE_CMD="nerdctl compose"
  else
    COMPOSE_CMD="docker compose"
  fi
fi

echo "starting caddy"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "http:  http://${HOST_BIND:-0.0.0.0}:${HTTP_PORT:-80}"
echo "https: https://${HOST_BIND:-0.0.0.0}:${HTTPS_PORT:-443}"
