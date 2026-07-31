#!/usr/bin/env bash
# hit /health (no auth) and / (expects 401 without credentials)

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
port="${HOST_PORT:-8080}"
base="http://${bind}:${port}"

echo "GET ${base}/health"
curl -sf "${base}/health" >/dev/null
echo "health ok"

echo "GET ${base}/ (expect 401 without auth)"
code="$(curl -s -o /dev/null -w '%{http_code}' "${base}/" || true)"
if [ "${code}" != "401" ]; then
  echo "expected 401, got ${code}"
  exit 1
fi
echo "auth challenge ok"

if [ -f secrets/password.txt ]; then
  user="${GATUS_AUTH_USER:-admin}"
  pass="$(tr -d '\r\n' < secrets/password.txt)"
  echo "GET ${base}/ with basic auth"
  curl -sf -u "${user}:${pass}" "${base}/" >/dev/null
  echo "authenticated ok"
else
  echo "skipping authed check - secrets/password.txt missing"
fi

echo "smoke done"
