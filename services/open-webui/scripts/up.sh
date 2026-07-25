#!/usr/bin/env bash

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env - copy .env.example to .env and edit"
  exit 1
fi

if [ ! -f compose.yml ]; then
  echo "missing compose.yml - copy compose.yml.template to compose.yml"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

if [ "${WEBUI_SECRET_KEY:-}" = "replace-with-a-random-secret" ] || [ -z "${WEBUI_SECRET_KEY:-}" ]; then
  echo "set WEBUI_SECRET_KEY in .env"
  exit 1
fi

network="${LLM_NETWORK:-llm-backend}"
if ! nerdctl network inspect "${network}" >/dev/null 2>&1; then
  echo "missing network ${network} - start llama-cpp first"
  exit 1
fi

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "starting open-webui"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "ui: http://${WEBUI_BIND:-127.0.0.1}:${WEBUI_PORT:-3000}"
