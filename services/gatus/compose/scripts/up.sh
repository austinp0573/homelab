#!/usr/bin/env bash
# bring gatus up

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

mkdir -p "${DATA_DIR:-./data}"

default_hash='JDJiJDEwJGJqc3JmbjVHWUxhaVhYQmdvRTVueU9NODRVZERmcEpUWU1tanBlbFhOQ3JZMGtwSHBqMjNp'
if grep -Fq "${default_hash}" config/10-security.yaml 2>/dev/null; then
  echo "config/10-security.yaml still has the default password hash"
  echo "set secrets/password.txt to a unique password and run ./scripts/hash-password.sh"
  exit 1
fi

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "starting gatus"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "ui: http://${HOST_BIND:-127.0.0.1}:${HOST_PORT:-8080}"
