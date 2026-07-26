#!/usr/bin/env bash
# restore a snapshot into a host directory.
# usage: ./scripts/restore.sh <snapshot-id|latest> /path/on/host [extra restic args]

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

SNAPSHOT="${1:-}"
RESTORE_PATH="${2:-}"

if [ -z "${SNAPSHOT}" ] || [ -z "${RESTORE_PATH}" ]; then
  echo "usage: $0 <snapshot-id|latest> /path/on/host"
  exit 1
fi

shift 2

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

mkdir -p "${RESTORE_PATH}"

echo "restoring ${SNAPSHOT} into ${RESTORE_PATH}"
${COMPOSE_CMD} run --rm \
  -v "${RESTORE_PATH}:/restore" \
  restic restore "${SNAPSHOT}" --target /restore "$@"

echo "restore finished"
