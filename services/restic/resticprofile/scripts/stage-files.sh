#!/bin/sh

# stage application files

set -eu
umask 077

log() {
    printf '[stage-files] %s\n' "$*"
}

# enable shell tracing when requested

case "${STAGE_DEBUG:-${LOG_LEVEL:-}}" in
    1|true|TRUE|debug|DEBUG) set -x ;;
esac

SRC_DIR="${SRC_DIR:-${APP_SOURCE_DIR:-}}"
STAGING_DIR="${STAGING_DIR:-${APP_STAGING_DIR:-}}"

: "${SRC_DIR:?error: SRC_DIR (or APP_SOURCE_DIR) environment variable is required}"
: "${STAGING_DIR:?error: STAGING_DIR (or APP_STAGING_DIR) environment variable is required}"

SRC_DIR="${SRC_DIR%/}/"
STAGING_DIR="${STAGING_DIR%/}/"

if [ ! -d "$SRC_DIR" ]; then
    printf 'error: source directory "%s" does not exist\n' "$SRC_DIR" >&2
    exit 1
fi

mkdir -p "$STAGING_DIR"

# default sqlite exclusions

DEFAULT_EXCLUDES="--exclude=*.db --exclude=*.db-wal --exclude=*.db-shm --exclude=*.db-journal --exclude=*.db3 --exclude=*.db3-wal --exclude=*.db3-shm --exclude=*.db3-journal --exclude=*.sqlite --exclude=*.sqlite-wal --exclude=*.sqlite-shm --exclude=*.sqlite-journal --exclude=*.sqlite3 --exclude=*.sqlite3-wal --exclude=*.sqlite3-shm --exclude=*.sqlite3-journal"

log "starting: source=$SRC_DIR destination=$STAGING_DIR"
log "rsync exclusions: ${RSYNC_EXTRA_ARGS:-$DEFAULT_EXCLUDES}"

# disable shell glob expansion so exclusion patterns are passed to rsync

set -f

rsync \
    -aHAXc \
    --omit-dir-times \
    --fsync \
    --delete \
    --itemize-changes \
    ${RSYNC_EXTRA_ARGS:-$DEFAULT_EXCLUDES} \
    --info=progress2 \
    "$SRC_DIR" \
    "$STAGING_DIR"

log 'completed successfully'
