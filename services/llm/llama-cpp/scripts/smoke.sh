#!/usr/bin/env bash
# quick check that the OpenAI-compatible API answers

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

port="${HOST_PORT:-8080}"
base="http://127.0.0.1:${port}"

echo "GET ${base}/health"
curl -sf "${base}/health" >/dev/null
echo "health ok"

echo "GET ${base}/v1/models"
curl -sf "${base}/v1/models"
echo

echo "POST ${base}/v1/chat/completions"
curl -sf "${base}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Say hi in one word."}],"max_tokens":16,"temperature":0}'
echo
echo "smoke done"
