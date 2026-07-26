#!/usr/bin/env bash
# stage one application directory before backup.
# regular files use rsync. sqlite files use sqlite .backup.

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

SOURCE="${APP_SOURCE_DIR:-}"
NAME="${BACKUP_NAME:-}"

if [ -z "${SOURCE}" ] || [ -z "${NAME}" ]; then
  echo "APP_SOURCE_DIR and BACKUP_NAME are required"
  exit 1
fi

if [ ! -d "${SOURCE}" ]; then
  echo "APP_SOURCE_DIR does not exist: ${SOURCE}"
  exit 1
fi

case "${NAME}" in
  *[!A-Za-z0-9._-]*)
    echo "BACKUP_NAME may only contain letters, numbers, dot, dash, and underscore"
    exit 1
    ;;
esac

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync not found"
  exit 1
fi

DEST="./staging/app/${NAME}"
mkdir -p "${DEST}"

echo "staging ${SOURCE} -> ${DEST}"
rsync -a --delete \
  --exclude '*-wal' \
  --exclude '*-shm' \
  --exclude '*-journal' \
  "${SOURCE}/" "${DEST}/"

mapfile -d '' -t databases < <(
  find "${SOURCE}" -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) -print0
)

if [ "${#databases[@]}" -eq 0 ]; then
  echo "staging finished"
  exit 0
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 not found"
  exit 1
fi

for database in "${databases[@]}"; do
  relative_path="${database#"${SOURCE}"/}"
  destination="${DEST}/${relative_path}"
  mkdir -p "$(dirname "${destination}")"
  echo "sqlite backup ${database}"
  sqlite3 "${database}" ".backup '${destination}'"
  rm -f "${destination}-wal" "${destination}-shm" "${destination}-journal"
done

echo "staging finished"
