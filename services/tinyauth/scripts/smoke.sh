#!/usr/bin/env bash
# local checks for tinyauth and gate

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

ta_port="${TINYAUTH_HOST_PORT:-3000}"
gate_port="${GATE_HOST_PORT:-8088}"

expect_one_of() {
  label="$1"
  code="$2"
  shift 2

  for expected in "$@"; do
    if [ "${code}" = "${expected}" ]; then
      echo "${label} status=${code}"
      return
    fi
  done

  echo "${label} expected $*, got ${code}"
  exit 1
}

echo "GET tinyauth /"
code="$(curl -s -o /dev/null -w '%{http_code}' "http://${bind}:${ta_port}/" || true)"
expect_one_of "tinyauth" "${code}" 200 301 302 303 307 308

echo "GET gate /health"
code="$(curl -s -o /dev/null -w '%{http_code}' "http://${bind}:${gate_port}/health" || true)"
expect_one_of "gate" "${code}" 200

echo "GET gate /auth-health"
code="$(curl -s -o /dev/null -w '%{http_code}' "http://${bind}:${gate_port}/auth-health" || true)"
expect_one_of "gate auth" "${code}" 401

echo "GET gate / with Host status.private.example.com"
code="$(curl -s -o /dev/null -w '%{http_code}' \
  -H "Host: status.private.example.com" \
  "http://${bind}:${gate_port}/" || true)"
expect_one_of "protected route" "${code}" 302

echo "smoke done"
echo "full browser test: https://auth.private.example.com then https://status.private.example.com"
