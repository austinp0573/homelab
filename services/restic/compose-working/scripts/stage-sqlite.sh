#!/bin/sh
# Generic POSIX /bin/sh script to perform an online hot backup & integrity check
# of a SQLite database before resticprofile backup runs.
set -eu

# temporary testing source line
[ -f .env ] && set -a && . ./.env && set +a

# Support generic or app-specific environment variable names
SQLITE_DB="${SQLITE_DB:-${DB_PATH:-}}"
STAGING_DIR="${STAGING_DIR:-${BACKUP_DIR:-${STAGE_DEST:-}}}"

: "${SQLITE_DB:?Error: SQLITE_DB (or DB_PATH) environment variable is required}"
: "${STAGING_DIR:?Error: STAGING_DIR (or STAGE_DEST) environment variable is required}"

BUSY_TIMEOUT="${BUSY_TIMEOUT:-15000}"
STAGING_DIR="${STAGING_DIR%/}"
DB_NAME="${STAGING_DB_NAME:-$(basename "$SQLITE_DB")}"

# Check for required sqlite3 binary
if ! command -v sqlite3 >/dev/null 2>&1; then
    printf 'Error: sqlite3 binary is not installed in the container environment.\n' >&2
    exit 1
fi

# Validate source database file exists
if [ ! -f "$SQLITE_DB" ]; then
    printf 'Error: Source SQLite database file "%s" does not exist.\n' "$SQLITE_DB" >&2
    exit 1
fi

# Ensure staging directory exists
mkdir -p "$STAGING_DIR"

TMP_BACKUP="$STAGING_DIR/.$DB_NAME.tmp"
FINAL_BACKUP="$STAGING_DIR/$DB_NAME"

# Step 1: Perform online SQLite backup (handles active WAL mode safely)
sqlite3 -readonly -bail -batch -init /dev/null \
  -cmd "PRAGMA busy_timeout = ${BUSY_TIMEOUT};" \
  "$SQLITE_DB" \
  ".backup '$TMP_BACKUP'"

# Step 2: Validate database integrity on the backup file
INTEGRITY="$(sqlite3 -readonly -bail -batch "$TMP_BACKUP" "PRAGMA integrity_check;")"

if [ "$INTEGRITY" != "ok" ]; then
    printf 'Error: SQLite integrity check failed for %s (result: %s)\n' "$TMP_BACKUP" "$INTEGRITY" >&2
    rm -f "$TMP_BACKUP" "$TMP_BACKUP-wal" "$TMP_BACKUP-shm" "$TMP_BACKUP-journal"
    exit 1
fi

# Step 3: Cleanup temporary WAL/SHM files, atomic rename, and cleanup final path
rm -f "$TMP_BACKUP-wal" "$TMP_BACKUP-shm" "$TMP_BACKUP-journal"
mv "$TMP_BACKUP" "$FINAL_BACKUP"
rm -f "$FINAL_BACKUP-wal" "$FINAL_BACKUP-shm" "$FINAL_BACKUP-journal"

printf 'Successfully staged SQLite database to %s\n' "$FINAL_BACKUP"