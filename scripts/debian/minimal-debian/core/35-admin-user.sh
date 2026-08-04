#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "admin user"

ADMIN_USER="${ADMIN_USER:-}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
ADMIN_GROUPS="${ADMIN_GROUPS:-sudo}"

if [ -z "$ADMIN_USER" ]; then
    echo ""
    echo ""
    echo "ADMIN USER MUST BE SET!"
    echo "SET IT AND RERUN"
    echo ""
    exit 1
fi

apt_install sudo

if ! id "$ADMIN_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$ADMIN_USER"
    echo "created $ADMIN_USER"
else
    echo "$ADMIN_USER already exists"
fi

for g in $ADMIN_GROUPS; do
    getent group "$g" >/dev/null || groupadd "$g"
    usermod -aG "$g" "$ADMIN_USER"
done

if [ -n "$ADMIN_PASSWORD" ]; then
    echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
    echo "password set"
else
    passwd -l "$ADMIN_USER" >/dev/null 2>&1 || true
    echo "password locked (key-only)"
fi

echo "admin user done"
