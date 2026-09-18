#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "disable root"

ADMIN_USER="${ADMIN_USER:-}"
ADMIN_SSH_KEYS="${ADMIN_SSH_KEYS:-}"
SAME_SSH_KEYS="${SAME_SSH_KEYS:-n}"
ROOT_SSH_KEYS="${ROOT_SSH_KEYS:-}"

admin_keys="$ADMIN_SSH_KEYS"
if is_yes "$SAME_SSH_KEYS"; then
    admin_keys="$ROOT_SSH_KEYS"
fi

if [ -z "$ADMIN_USER" ]; then
    echo "ADMIN_USER must be set"
    exit 1
fi

if [ -z "$admin_keys" ]; then
    echo "admin SSH keys are required before disabling root"
    exit 1
fi

passwd -l root >/dev/null 2>&1 || true

DROPBEAR_SSH="${DROPBEAR_SSH:-n}"
if is_yes "$DROPBEAR_SSH"; then
    if [ -f /etc/default/dropbear ] && grep -q '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear; then
        current="$(grep '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear | sed 's/^DROPBEAR_EXTRA_ARGS=//' | tr -d '"')"
        case " $current " in
            *" -w "*) ;;
            *) current="$current -w" ;;
        esac
        sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"$current\"/" /etc/default/dropbear
    else
        echo 'DROPBEAR_EXTRA_ARGS="-w"' > /etc/default/dropbear
    fi
    systemctl restart dropbear
    echo "dropbear: root logins disabled"
else
    ensure_dir /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/90-disable-root.conf << 'EOF'
PermitRootLogin no
EOF
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    echo "openssh: root logins disabled"
fi
