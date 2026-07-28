#!/usr/bin/env bash
# start qdrant + embed server

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

models_dir="${MODELS_DIR:-/opt/llm/models}"
embed_file="${EMBED_MODEL_FILE:-}"

if [ -z "${embed_file}" ] || [ ! -f "${models_dir}/${embed_file}" ]; then
  echo "embed model not found: ${models_dir}/${embed_file}"
  exit 1
fi

mkdir -p "${QDRANT_DATA_DIR:-/opt/llm/rag/qdrant}" "${DOCS_DIR:-/opt/llm/rag/docs}"

network="${LLM_NETWORK:-llm-backend}"
if ! nerdctl network inspect "${network}" >/dev/null 2>&1; then
  echo "creating network ${network}"
  nerdctl network create "${network}" >/dev/null
fi

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "starting rag-headless"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "qdrant: http://127.0.0.1:${QDRANT_HOST_PORT:-6333}"
echo "embed:  http://127.0.0.1:${EMBED_HOST_PORT:-8081}/v1"
