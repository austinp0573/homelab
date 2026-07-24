#!/usr/bin/env bash
# start tinyauth + gate

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env - copy .env.example to .env and edit"
  exit 1
fi

if [ ! -f config/users ]; then
  echo "missing config/users - copy config/users.example and run ./scripts/create-user.sh"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

users=""
while IFS= read -r line || [ -n "${line}" ]; do
  case "${line}" in
    ""|\#*) continue ;;
  esac
  if [ -z "${users}" ]; then
    users="${line}"
  else
    users="${users},${line}"
  fi
done < config/users

if [ -z "${users}" ]; then
  echo "config/users has no users"
  exit 1
fi

export TINYAUTH_AUTH_USERS="${users}"
echo "loaded users from config/users"

mkdir -p "${DATA_DIR:-./data}"

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "starting tinyauth"
${COMPOSE_CMD} up -d "$@"
echo "up done"
echo "tinyauth: http://${HOST_BIND:-127.0.0.1}:${TINYAUTH_HOST_PORT:-3000}"
echo "gate:     http://${HOST_BIND:-127.0.0.1}:${GATE_HOST_PORT:-8088}"
echo "public login should be ${TINYAUTH_APPURL:-https://auth.private.example.com}"
