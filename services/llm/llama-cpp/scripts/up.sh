#!/usr/bin/env bash
# bring llama-server up

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
model_file="${MODEL_FILE:-}"

if [ -z "${model_file}" ]; then
  echo "MODEL_FILE is empty in .env"
  exit 1
fi

if [ ! -f "${models_dir}/${model_file}" ]; then
  echo "model not found: ${models_dir}/${model_file}"
  exit 1
fi

"${TARGET_DIR}/scripts/ensure-network.sh" "${LLM_NETWORK:-llm-backend}"

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "starting llama-cpp with ${model_file}"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "api: http://${HOST_BIND:-127.0.0.1}:${HOST_PORT:-8080}/v1"
