#!/usr/bin/env bash
# stage one live sqlite database with .backup for a later restic run.
#
# required environment variables:
#   SQLITE_DB    absolute path to the live database file
#   STAGE_DEST   staging directory restic will read (file is written as
#                STAGE_DEST/$(basename SQLITE_DB))
#
# example:
#   SQLITE_DB=/srv/vaultwarden/db.sqlite3
#   STAGE_DEST=./staging/app/vaultwarden
#
# run from the compose tree, or set the variables in .env there.

set -euo pipefail

# SQLITE_DB=
# STAGE_DEST=

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

SQLITE_DB="${SQLITE_DB:-}"
STAGE_DEST="${STAGE_DEST:-}"

if [ -z "${SQLITE_DB}" ] || [ -z "${STAGE_DEST}" ]; then
  echo "SQLITE_DB and STAGE_DEST are required"
  exit 1
fi

if [ ! -f "${SQLITE_DB}" ]; then
  echo "SQLITE_DB not found: ${SQLITE_DB}"
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 not found"
  exit 1
fi

DB_NAME="$(basename "${SQLITE_DB}")"
DEST_FILE="${STAGE_DEST%/}/${DB_NAME}"
TMP_FILE="${DEST_FILE}.tmp.$$"

case "${DEST_FILE}" in
  *"'"*)
    echo "STAGE_DEST path contains an unsupported single quote"
    exit 1
    ;;
esac

mkdir -p "${STAGE_DEST}"
trap 'rm -f "${TMP_FILE}"' EXIT INT TERM

echo "sqlite backup ${SQLITE_DB} -> ${DEST_FILE}"
sqlite3 "${SQLITE_DB}" ".timeout 10000" ".backup '${TMP_FILE}'"
mv -f "${TMP_FILE}" "${DEST_FILE}"
rm -f "${DEST_FILE}-wal" "${DEST_FILE}-shm" "${DEST_FILE}-journal"

echo "staging finished"
