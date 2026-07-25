#!/usr/bin/env bash
# hit /api/v1/health

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
port="${HOST_PORT:-8789}"
base="http://${bind}:${port}"
wait_seconds="${SMOKE_WAIT_SECONDS:-40}"

echo "GET ${base}/api/v1/health"
for _ in $(seq 1 "${wait_seconds}"); do
  if curl -sf "${base}/api/v1/health" >/dev/null 2>&1; then
    echo "health ok"
    echo "smoke done"
    exit 0
  fi
  sleep 1
done

echo "health check failed after ${wait_seconds}s"
exit 1
