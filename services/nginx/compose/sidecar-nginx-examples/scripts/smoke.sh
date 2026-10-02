#!/usr/bin/env bash
# basic smoke check

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

URL="http://${CONNECT_HOST}:${HOST_PORT:-8080}/"
WAIT_SECONDS="${SMOKE_WAIT_SECONDS:-20}"

echo "checking ${URL}"
for _ in $(seq 1 "${WAIT_SECONDS}"); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "${URL}" || true)"
  if [ "${code}" != "000" ] && [ -n "${code}" ]; then
    break
  fi
  sleep 1
done

code="$(curl -s -o /dev/null -w '%{http_code}' "${URL}" || true)"
echo "http ${code}"

# 200 for open proxy/static, 401 when basic auth is on
if [ "${code}" = "200" ] || [ "${code}" = "401" ]; then
  echo "smoke ok"
  exit 0
fi

echo "unexpected status"
exit 1
