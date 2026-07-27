#!/usr/bin/env bash

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

mkdir -p \
  "${EBOOKS_DIR:-/opt/llm/ebooks}" \
  "${AUDIOBOOKS_DIR:-/opt/llm/audiobooks}" \
  "${MODELS_DIR:-/opt/llm/ebook-models}" \
  "${VOICES_DIR:-/opt/llm/ebook-voices}" \
  "${TMP_DIR:-/opt/llm/ebook-tmp}"

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "starting ebook2audiobook"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "ui: http://${EBOOK_BIND:-127.0.0.1}:${EBOOK_PORT:-7860}"
