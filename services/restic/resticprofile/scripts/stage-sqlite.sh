#!/bin/sh

# stage a validated sqlite database backup

set -eu
umask 077

log() {
    printf '[stage-sqlite] %s\n' "$*"
}

# enable shell tracing when requested

case "${STAGE_DEBUG:-${LOG_LEVEL:-}}" in
    1|true|TRUE|debug|DEBUG) set -x ;;
esac

SQLITE_DB="${SQLITE_DB:-${DB_PATH:-}}"
STAGING_DIR="${STAGING_DIR:-${BACKUP_DIR:-${STAGE_DEST:-}}}"

: "${SQLITE_DB:?error: SQLITE_DB (or DB_PATH) environment variable is required}"
: "${STAGING_DIR:?error: STAGING_DIR (or STAGE_DEST) environment variable is required}"

BUSY_TIMEOUT="${BUSY_TIMEOUT:-30000}"

STAGING_DIR="${STAGING_DIR%/}"
TMP_DIR="${SQLITE_TMP_DIR:-/staging/.sqlite-tmp}"
TMP_DIR="${TMP_DIR%/}"

DB_NAME="${STAGING_DB_NAME:-$(basename "$SQLITE_DB")}"

# verify the required sqlite client exists

if ! command -v sqlite3 >/dev/null 2>&1; then
    printf 'error: sqlite3 binary is not installed in the container environment\n' >&2
    exit 1
fi

# verify the source database exists

if [ ! -f "$SQLITE_DB" ]; then
    printf 'error: source sqlite database file "%s" does not exist\n' \
        "$SQLITE_DB" >&2
    exit 1
fi

# the current compose layout requires staging paths below /staging

case "$STAGING_DIR/" in
    /staging/*) ;;
    *)
        printf 'error: staging directory "%s" must be below /staging\n' \
            "$STAGING_DIR" >&2
        exit 1
        ;;
esac

case "$TMP_DIR/" in
    /staging/*) ;;
    *)
        printf 'error: sqlite temporary directory "%s" must be below /staging\n' \
            "$TMP_DIR" >&2
        exit 1
        ;;
esac

mkdir -p "$STAGING_DIR" "$TMP_DIR"

FINAL_BACKUP="$STAGING_DIR/$DB_NAME"
TMP_BACKUP="$(mktemp "$TMP_DIR/.${DB_NAME}.tmp.XXXXXX")"

log "starting: source=$SQLITE_DB destination=$FINAL_BACKUP temp-dir=$TMP_DIR busy-timeout=${BUSY_TIMEOUT}ms"

cleanup_tmp() {
    rm -f \
        "$TMP_BACKUP" \
        "$TMP_BACKUP-wal" \
        "$TMP_BACKUP-shm" \
        "$TMP_BACKUP-journal"
}

trap cleanup_tmp 0
trap 'exit 1' 1 2 3 15

# create an online sqlite backup

log 'creating online sqlite backup'

{
    printf 'PRAGMA busy_timeout = %s;\n' "$BUSY_TIMEOUT"
    printf ".backup '%s'\n" "$TMP_BACKUP"
} | sqlite3 \
    -bail \
    -batch \
    -init /dev/null \
    "file:${SQLITE_DB}?mode=ro" \
    >/dev/null

# mktemp creates the file before sqlite runs, so require non-empty output

if [ ! -s "$TMP_BACKUP" ]; then
    printf 'error: sqlite backup did not create a non-empty database at "%s"\n' \
        "$TMP_BACKUP" >&2
    exit 1
fi

# validate the staged database

log 'validating sqlite integrity'

INTEGRITY="$(
    sqlite3 \
        -readonly \
        -bail \
        -batch \
        "$TMP_BACKUP" \
        "PRAGMA integrity_check;"
)"

if [ "$INTEGRITY" != "ok" ]; then
    printf 'error: sqlite integrity check failed for %s: %s\n' \
        "$TMP_BACKUP" "$INTEGRITY" >&2
    exit 1
fi

log 'integrity check passed'

# preserve the existing staged file when the database is unchanged

if [ -f "$FINAL_BACKUP" ] && cmp -s "$TMP_BACKUP" "$FINAL_BACKUP"; then
    log "database unchanged; retaining staged copy at $FINAL_BACKUP"
else
    mv -f "$TMP_BACKUP" "$FINAL_BACKUP"
    log "database changed; staged validated copy at $FINAL_BACKUP"
fi

# never retain sqlite sidecar files with an online backup

rm -f \
    "$FINAL_BACKUP-wal" \
    "$FINAL_BACKUP-shm" \
    "$FINAL_BACKUP-journal"

log 'completed successfully'
