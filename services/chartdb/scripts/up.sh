#!/usr/bin/env bash
# bring chartdb up

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env - copy .env.example to .env and edit"
  exit 1
fi

if [ ! -f secrets/htpasswd ]; then
  echo "missing secrets/htpasswd - run ./scripts/htpasswd.sh first"
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

echo "starting chartdb"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "ui (no auth):  http://${HOST_BIND:-127.0.0.1}:${HOST_PORT:-8792}"
echo "auth (proxy):  http://${HOST_BIND:-127.0.0.1}:${AUTH_HOST_PORT:-8793}"
