#!/bin/sh
# Generic POSIX /bin/sh script to stage application files
set -eu

# temporary testing source line
[ -f .env ] && set -a && . ./.env && set +a

SRC_DIR="${SRC_DIR:-${APP_SOURCE_DIR:-}}"
STAGING_DIR="${STAGING_DIR:-${APP_STAGING_DIR:-}}"

: "${SRC_DIR:?Error: SRC_DIR (or APP_SOURCE_DIR) environment variable is required}"
: "${STAGING_DIR:?Error: STAGING_DIR (or APP_STAGING_DIR) environment variable is required}"

SRC_DIR="${SRC_DIR%/}/"
STAGING_DIR="${STAGING_DIR%/}/"

if [ ! -d "$SRC_DIR" ]; then
    printf 'Error: Source directory "%s" does not exist.\n' "$SRC_DIR" >&2
    exit 1
fi

mkdir -p "$STAGING_DIR"

# Default rsync flags/excludes if RSYNC_EXTRA_ARGS is not defined in .env
DEFAULT_EXCLUDES="--exclude=*.db* --exclude=*.sqlite* --exclude=*-wal --exclude=*-shm --exclude=*-journal"

# Disable shell glob expansion (set -f) so wildcard patterns in RSYNC_EXTRA_ARGS are passed directly to rsync
set -f
exec rsync -aHAXc --fsync --delete \
  ${RSYNC_EXTRA_ARGS:-$DEFAULT_EXCLUDES} \
  --info=progress2 \
  "$SRC_DIR" "$STAGING_DIR"