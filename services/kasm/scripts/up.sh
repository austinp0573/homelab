#!/usr/bin/env bash
# bring kasm up

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env - copy .env.example to .env and edit"
  exit 1
fi

if [ ! -f secrets/vnc.env ]; then
  echo "missing secrets/vnc.env - copy secrets/vnc.env.example to secrets/vnc.env and set VNC_PW"
  exit 1
fi

if grep -qE '^VNC_PW=(changeme|password)\s*$' secrets/vnc.env; then
  echo "secrets/vnc.env still has a placeholder VNC_PW - set a real password"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

mkdir -p "${DATA_DIR:-./data}"

COMPOSE_CMD="${COMPOSE_CMD:-}"
if [ -z "${COMPOSE_CMD}" ]; then
  if command -v nerdctl >/dev/null 2>&1; then
    COMPOSE_CMD="nerdctl compose"
  else
    COMPOSE_CMD="docker compose"
  fi
fi

echo "starting kasm"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "ui: https://${HOST_BIND:-127.0.0.1}:${HOST_PORT:-6901}"
echo "login user: kasm_user"
echo "cert is self-signed - browser will warn unless you terminate tls on a proxy"
