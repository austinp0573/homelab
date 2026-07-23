#!/usr/bin/env bash
# local health check

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
port="${HOST_PORT:-2586}"
base="http://${bind}:${port}"

echo "GET ${base}/v1/health"
curl -sf "${base}/v1/health"
echo
echo "smoke done"
