#!/usr/bin/env bash
# stage vaultwarden data for restic. sqlite hot copy, skip icon_cache.
# run from /opt/restic-vw-backup/ (or any checkout of this compose tree).

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${TARGET_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

SOURCE="${VW_DATA_DIR:-/opt/vaultwarden-cloudflared/vaultwarden-data}"
DEST="${STAGE_DEST:-./staging/vaultwarden-data}"

if [ ! -d "${SOURCE}" ]; then
  echo "VW_DATA_DIR missing: ${SOURCE}"
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 not found"
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync not found"
  exit 1
fi

echo "staging ${SOURCE} -> ${DEST}"
mkdir -p "${DEST}"

rsync -a --delete \
  --exclude 'icon_cache/' \
  --exclude '*.db-wal' \
  --exclude '*.db-shm' \
  --exclude '*.db-journal' \
  "${SOURCE}/" "${DEST}/"

DB_SRC="${SOURCE}/db.sqlite3"
DB_DST="${DEST}/db.sqlite3"

if [ ! -f "${DB_SRC}" ]; then
  echo "db.sqlite3 not found at ${DB_SRC}"
  exit 1
fi

echo "sqlite hot copy ${DB_SRC}"
sqlite3 "${DB_SRC}" ".backup '${DB_DST}'"

echo "staging finished"
