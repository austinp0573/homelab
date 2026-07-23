#!/usr/bin/env bash
# check the kasmvnc https port answers (self-signed cert)

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
port="${HOST_PORT:-6901}"
base="https://${bind}:${port}"
WAIT_SECONDS="${SMOKE_WAIT_SECONDS:-90}"

echo "waiting for ${base}"
code=""
for _ in $(seq 1 "${WAIT_SECONDS}"); do
  code="$(curl -k -s -o /dev/null -w '%{http_code}' "${base}/" || true)"
  if [ "${code}" = "200" ] || [ "${code}" = "401" ]; then
    break
  fi
  sleep 1
done

if [ "${code}" != "200" ] && [ "${code}" != "401" ]; then
  echo "expected 200 or 401, got ${code:-none}"
  exit 1
fi
echo "ui http ${code}"

if [ -f secrets/vnc.env ]; then
  # shellcheck disable=SC1091
  set -a
  source secrets/vnc.env
  set +a
  if [ -n "${VNC_PW:-}" ]; then
    echo "checking basic auth as kasm_user"
    curl -k -sf -u "kasm_user:${VNC_PW}" "${base}/" >/dev/null
    echo "auth ok"
  fi
else
  echo "skipping authed check - secrets/vnc.env missing"
fi

echo "smoke done"
