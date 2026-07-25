#!/usr/bin/env bash
# bring nocodb up

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

if [ -z "${NC_AUTH_JWT_SECRET:-}" ] || [ "${NC_AUTH_JWT_SECRET}" = "change-me" ]; then
  echo "warning: NC_AUTH_JWT_SECRET is empty or still change-me"
  echo "warning: set a real secret in .env (openssl rand -base64 32) or logins will break on restart"
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

echo "starting nocodb"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "ui: http://${HOST_BIND:-127.0.0.1}:${HOST_PORT:-8789}"
