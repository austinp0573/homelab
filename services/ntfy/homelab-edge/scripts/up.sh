#!/usr/bin/env bash
# bring ntfy up

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env - copy .env.example to .env and edit"
  exit 1
fi

if [ ! -f config/server.yml ]; then
  echo "missing config/server.yml - copy config/server.yml.example to config/server.yml and edit"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

mkdir -p "${DATA_DIR:-./data}" "${CACHE_DIR:-./cache}" "${CACHE_DIR:-./cache}/attachments"

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "starting ntfy"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "local: http://${HOST_BIND:-127.0.0.1}:${HOST_PORT:-2586}"
echo "public base-url should be ${BASE_URL:-https://ntfy.example.com}"
