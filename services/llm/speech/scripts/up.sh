#!/usr/bin/env bash
# build and start whisper + piper

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

mkdir -p "${WHISPER_CACHE_DIR:-/opt/llm/whisper}" "${TTS_DIR:-/opt/llm/tts}"

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "building whisper image (first time is slow)"
${COMPOSE_CMD} build whisper

echo "starting speech stack"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "whisper: http://${WHISPER_BIND:-127.0.0.1}:${WHISPER_HOST_PORT:-9000}"
echo "piper wyoming: tcp://${PIPER_BIND:-127.0.0.1}:${PIPER_HOST_PORT:-10200}"
