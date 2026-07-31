#!/usr/bin/env bash
# basic smoke check for excalidraw

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
CONNECT_HOST="${HOST_BIND}"
if [ "${CONNECT_HOST}" = "0.0.0.0" ]; then
  CONNECT_HOST="127.0.0.1"
fi

UI="http://${CONNECT_HOST}:${UI_HOST_PORT:-5000}"
ROOM="http://${CONNECT_HOST}:${ROOM_HOST_PORT:-5001}"
WAIT_SECONDS="${SMOKE_WAIT_SECONDS:-30}"

echo "checking ui ${UI}"
for _ in $(seq 1 "${WAIT_SECONDS}"); do
  if curl -fsS "${UI}/" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl -fsS "${UI}/" >/dev/null

echo "checking room ${ROOM}"
# room may not return a useful body; any http response means it is listening
code="$(curl -s -o /dev/null -w '%{http_code}' "${ROOM}/" || true)"
if [ -z "${code}" ] || [ "${code}" = "000" ]; then
  echo "room not answering on ${ROOM}"
  exit 1
fi
echo "room http ${code}"

if [ "${ENABLE_BASIC_AUTH:-n}" = "y" ] || [ "${ENABLE_BASIC_AUTH:-n}" = "Y" ]; then
  AUTH="http://${CONNECT_HOST}:${AUTH_HOST_PORT:-5002}"
  echo "checking auth ${AUTH}"
  auth_code="$(curl -s -o /dev/null -w '%{http_code}' "${AUTH}/" || true)"
  if [ "${auth_code}" != "401" ]; then
    echo "expected 401 from auth sidecar, got ${auth_code}"
    exit 1
  fi
fi

echo "smoke ok"
