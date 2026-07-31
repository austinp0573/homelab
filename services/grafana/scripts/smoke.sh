#!/usr/bin/env bash
# hit /api/health

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

bind="${GF_SERVER_HTTP_ADDR:-127.0.0.1}"
if [ "${bind}" = "0.0.0.0" ]; then
  bind="127.0.0.1"
fi
port="${GF_SERVER_HTTP_PORT:-3000}"
base="http://${bind}:${port}"

echo "GET ${base}/api/health"
curl -sf "${base}/api/health" >/dev/null
echo "health ok"
echo "smoke done"
