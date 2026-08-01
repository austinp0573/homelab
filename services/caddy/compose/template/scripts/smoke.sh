#!/usr/bin/env bash
# check that caddy is listening on the http port

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

bind="${HOST_BIND:-0.0.0.0}"
if [ "${bind}" = "0.0.0.0" ]; then
  bind="127.0.0.1"
fi
port="${HTTP_PORT:-80}"
base="http://${bind}:${port}"

echo "GET ${base}/"
code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 "${base}/" || true)"
if [ -z "${code}" ] || [ "${code}" = "000" ]; then
  echo "no response from ${base}"
  exit 1
fi
echo "got http ${code}"
echo "smoke done"
