#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "ssh keys"

ROOT_SSH_KEYS="${ROOT_SSH_KEYS:-}"
ADMIN_SSH_KEYS="${ADMIN_SSH_KEYS:-}"
SAME_SSH_KEYS="${SAME_SSH_KEYS:-n}"
ADMIN_USER="${ADMIN_USER:-}"

install_for_user() {
    local user="$1"
    local keys="$2"
    local home ssh_dir auth
    if [ "$user" = "root" ]; then
        home="/root"
    else
        if ! id "$user" >/dev/null 2>&1; then
            echo "user $user does not exist, skipping keys"
            return 0
        fi
        home="$(getent passwd "$user" | cut -d: -f6)"
    fi
    ssh_dir="$home/.ssh"
    auth="$ssh_dir/authorized_keys"
    ensure_dir "$ssh_dir"
    write_keys_file "$auth" "$keys"
    chmod 700 "$ssh_dir"
    chmod 600 "$auth"
    if [ "$user" != "root" ]; then
        chown -R "$user:$user" "$ssh_dir"
    else
        chown -R root:root "$ssh_dir"
    fi
    echo "keys installed for $user"
}

if [ -n "$ROOT_SSH_KEYS" ]; then
    install_for_user root "$ROOT_SSH_KEYS"
else
    echo "ROOT_SSH_KEYS empty, skipping root"
fi

admin_keys="$ADMIN_SSH_KEYS"
if is_yes "$SAME_SSH_KEYS"; then
    admin_keys="$ROOT_SSH_KEYS"
fi

if [ -n "$ADMIN_USER" ] && [ -n "$admin_keys" ]; then
    install_for_user "$ADMIN_USER" "$admin_keys"
elif [ -n "$ADMIN_USER" ]; then
    echo "no admin keys to install"
fi
