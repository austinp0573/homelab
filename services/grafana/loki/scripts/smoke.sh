#!/usr/bin/env bash
# hit loki ready

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

bind="${HOST_BIND:-127.0.0.1}"
if [ "${bind}" = "0.0.0.0" ]; then
  bind="127.0.0.1"
fi
port="${HOST_PORT:-3100}"

echo "GET http://${bind}:${port}/ready"
curl -sf "http://${bind}:${port}/ready" >/dev/null
echo "loki ok"
echo "smoke done"
