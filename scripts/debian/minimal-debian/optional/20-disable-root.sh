#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "disable root access"

ADMIN_USER="${ADMIN_USER:-}"
DROPBEAR_SSH="${DROPBEAR_SSH:-y}"

if [ -z "$ADMIN_USER" ] || ! id "$ADMIN_USER" >/dev/null 2>&1; then
    echo "ADMIN_USER must exist before disabling root"
    exit 1
fi

admin_home="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
if [ ! -s "$admin_home/.ssh/authorized_keys" ]; then
    echo "admin SSH keys must be installed before disabling root"
    exit 1
fi

passwd -l root >/dev/null 2>&1 || true

if is_yes "$DROPBEAR_SSH"; then
    # dropbear: -w disables root logins
    if [ -f /etc/default/dropbear ]; then
        if grep -q '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear; then
            current="$(grep '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear | sed 's/^DROPBEAR_EXTRA_ARGS=//' | tr -d '"')"
            case " $current " in
                *" -w "*) ;;
                *) current="$current -w" ;;
            esac
            sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"$current\"/" /etc/default/dropbear
        else
            echo 'DROPBEAR_EXTRA_ARGS="-w"' >> /etc/default/dropbear
        fi
    else
        echo 'DROPBEAR_EXTRA_ARGS="-w"' > /etc/default/dropbear
    fi
    systemctl restart dropbear 2>/dev/null || true
else
    ensure_dir /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/99-disable-root.conf << 'EOF'
PermitRootLogin no
EOF
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
fi

# clear root authorized_keys so key login is gone too
if [ -f /root/.ssh/authorized_keys ]; then
    : > /root/.ssh/authorized_keys
fi

echo "root access disabled (user kept)"
