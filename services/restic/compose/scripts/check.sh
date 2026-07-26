#!/usr/bin/env bash
# repository integrity check

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env in ${TARGET_DIR}"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

if [ -n "${REST_USERNAME_FILE:-}" ] && [ -f "${REST_USERNAME_FILE}" ]; then
  export RESTIC_REST_USERNAME="$(tr -d '\r\n' < "${REST_USERNAME_FILE}")"
fi
if [ -n "${REST_PASSWORD_FILE:-}" ] && [ -f "${REST_PASSWORD_FILE}" ]; then
  export RESTIC_REST_PASSWORD="$(tr -d '\r\n' < "${REST_PASSWORD_FILE}")"
fi

mkdir -p /var/cache/restic/tmp

echo "running restic check"
${COMPOSE_CMD} run --rm restic check "$@"
echo "check finished"
