#!/bin/sh
# Usage: backup-sqlite.sh /path/to/source.db /path/to/backup.db

set -eu

SRC=${1:-}
DEST=${2:-}

if [ -z "$SRC" ] || [ -z "$DEST" ]; then
  echo "usage: $0 source.db dest.db" >&2
  exit 1
fi

if [ ! -f "$SRC" ]; then
  echo "error: source not found: $SRC" >&2
  exit 1
fi

DEST_DIR=$(dirname "$DEST")
mkdir -p "$DEST_DIR"

TMP=$DEST.tmp.$$
trap 'rm -f "$TMP"' EXIT INT TERM

sqlite3 "$SRC" ".timeout 10000" ".backup '$TMP'"
mv -f "$TMP" "$DEST"

echo "backed up $SRC -> $DEST"


# chmod +x backup-sqlite.sh
# ./backup-sqlite.sh /srv/vaultwarden/db.sqlite3 /var/backups/vaultwarden/db.sqlite3
