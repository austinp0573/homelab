#!/usr/bin/env bash
# basic smoke check for gen-restic

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

HOST_BIND="${HOST_BIND:-127.0.0.1}"
HOST_PORT="${HOST_PORT:-8788}"
CONNECT_HOST="${HOST_BIND}"
if [ "${CONNECT_HOST}" = "0.0.0.0" ]; then
  CONNECT_HOST="127.0.0.1"
fi
BASE="http://${CONNECT_HOST}:${HOST_PORT}"
WAIT_SECONDS="${SMOKE_WAIT_SECONDS:-20}"

echo "checking ${BASE}"
for _ in $(seq 1 "${WAIT_SECONDS}"); do
  if curl -fsS "${BASE}/" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl -fsS "${BASE}/" >/dev/null
curl -fsS "${BASE}/js/app.js" >/dev/null
curl -fsS "${BASE}/js/generator.js" >/dev/null
curl -fsS "${BASE}/css/app.css" >/dev/null
echo "smoke ok"
