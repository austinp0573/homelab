#!/usr/bin/env bash
# start AnythingLLM

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

mkdir -p "${DOCS_DIR:-/opt/llm/rag/docs}"

network="${LLM_NETWORK:-llm-backend}"
if ! nerdctl network inspect "${network}" >/dev/null 2>&1; then
  echo "missing network ${network} - start llama-cpp first"
  exit 1
fi

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "starting rag-ui"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "ui: http://${HOST_BIND:-127.0.0.1}:${HOST_PORT:-3001}"
