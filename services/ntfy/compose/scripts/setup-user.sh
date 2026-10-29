#!/bin/sh
set -eu

# Default PUID/PGID and username/groupname
PUID="${PUID:-1020}"
PGID="${PGID:-1020}"
NTFY_USER="${NTFY_USER:-ntfy}"
NTFY_GROUP="${NTFY_GROUP:-ntfy}"

echo "Setting up system group '$NTFY_GROUP' ($PGID) and user '$NTFY_USER' ($PUID)..."

# Create group if it doesn't exist
if getent group "$NTFY_GROUP" >/dev/null 2>&1; then
    echo "Group '$NTFY_GROUP' already exists."
else
    echo "Creating group '$NTFY_GROUP' with GID $PGID..."
    sudo groupadd -g "$PGID" "$NTFY_GROUP"
fi

# Create user if it doesn't exist
if id -u "$NTFY_USER" >/dev/null 2>&1; then
    echo "User '$NTFY_USER' already exists."
else
    echo "Creating user '$NTFY_USER' with UID $PUID..."
    sudo useradd -r -u "$PUID" -g "$NTFY_GROUP" -s /usr/sbin/nologin "$NTFY_USER"
fi

# Resolve directories (POSIX compliant)
SCRIPT_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd)
BASE_DIR=$(cd -P -- "$SCRIPT_DIR/.." && pwd)

echo "Ensuring data and cache directories exist..."
mkdir -p "$BASE_DIR/data" "$BASE_DIR/cache"
sudo chown -R "$PUID:$PGID" "$BASE_DIR/data" "$BASE_DIR/cache"

echo "Setup complete! ntfy system user and directory permissions are ready."
