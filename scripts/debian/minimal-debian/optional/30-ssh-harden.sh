#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "ssh harden"

DROPBEAR_SSH="${DROPBEAR_SSH:-y}"

if is_yes "$DROPBEAR_SSH"; then
    # -s = disable password logins (root disable is optional/20-disable-root.sh)
    if [ -f /etc/default/dropbear ] && grep -q '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear; then
        # keep existing flags (e.g. -w) and ensure -s is present
        current="$(grep '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear | sed 's/^DROPBEAR_EXTRA_ARGS=//' | tr -d '"')"
        case " $current " in
            *" -s "*) ;;
            *) current="$current -s" ;;
        esac
        sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"$current\"/" /etc/default/dropbear
    else
        echo 'DROPBEAR_EXTRA_ARGS="-s"' > /etc/default/dropbear
    fi
    systemctl restart dropbear
    echo "dropbear: password auth off"
else
    ensure_dir /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/99-harden.conf << 'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
AllowAgentForwarding no
EOF
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    echo "openssh hardened"
fi
