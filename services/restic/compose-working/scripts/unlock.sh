#!/bin/sh
# remove stale locks. only use if a backup died mid-run and left a lock.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="${COMPOSE_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
cd "${COMPOSE_DIR}" || exit 1

if [ ! -f .env ]; then
  echo "missing .env in ${COMPOSE_DIR}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. .env
set +a

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

if [ -n "${REST_USERNAME_FILE:-}" ] && [ -f "${REST_USERNAME_FILE}" ]; then
  export RESTIC_REST_USERNAME="$(tr -d '\r\n' < "${REST_USERNAME_FILE}")"
fi
if [ -n "${REST_PASSWORD_FILE:-}" ] && [ -f "${REST_PASSWORD_FILE}" ]; then
  export RESTIC_REST_PASSWORD="$(tr -d '\r\n' < "${REST_PASSWORD_FILE}")"
fi

echo "unlocking repository"
${COMPOSE_CMD} run --rm restic --insecure-tls unlock "$@"
echo "unlock finished"
