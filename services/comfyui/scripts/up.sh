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

mkdir -p "${COMFYUI_DATA_DIR:-/opt/comfyui/data}"/{models,input,output,user}

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "starting comfyui"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "ui: http://${COMFYUI_BIND:-127.0.0.1}:${COMFYUI_PORT:-8188}"
