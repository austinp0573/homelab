#!/usr/bin/env bash

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

qdrant="http://127.0.0.1:${QDRANT_HOST_PORT:-6333}"
embed="http://127.0.0.1:${EMBED_HOST_PORT:-8081}/v1"

echo "checking qdrant"
curl -sf "${qdrant}/readyz" >/dev/null
echo "qdrant ok"

echo "checking embeddings"
curl -sf "${embed}/embeddings" \
  -H 'Content-Type: application/json' \
  -d '{"input":"smoke test","model":"embed"}' >/dev/null
echo "embeddings ok"
