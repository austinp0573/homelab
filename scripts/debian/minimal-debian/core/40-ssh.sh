#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "ssh"

DROPBEAR_SSH="${DROPBEAR_SSH:-y}"

set_dropbear_extra_args() {
    if [ -f /etc/default/dropbear ]; then
        if grep -q '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear; then
            return 0
        fi
    fi
}

dropbear_listening() {
    systemctl is-active --quiet dropbear 2>/dev/null || return 1
    # port 22 in use by dropbear if ss exists; otherwise trust active
    if command -v ss >/dev/null 2>&1; then
        ss -lntp 2>/dev/null | grep -q dropbear || return 1
    fi
    return 0
}

if is_yes "$DROPBEAR_SSH"; then
    # free :22 before installing/starting dropbear (package postinst may start it)
    systemctl stop ssh 2>/dev/null || true
    systemctl stop sshd 2>/dev/null || true
    pkill -x sshd 2>/dev/null || true
    sleep 1

    apt_install dropbear openssh-sftp-server openssh-client
    set_dropbear_extra_args

    systemctl stop dropbear 2>/dev/null || true
    systemctl reset-failed dropbear 2>/dev/null || true

    # openssh must be gone / not listening before dropbear binds
    systemctl disable ssh 2>/dev/null || true
    systemctl disable sshd 2>/dev/null || true
    apt_purge openssh-server
    systemctl stop ssh 2>/dev/null || true
    pkill -x sshd 2>/dev/null || true
    sleep 1

    systemctl unmask dropbear 2>/dev/null || true
    systemctl enable dropbear

    i=0
    while [ "$i" -lt 8 ]; do
        systemctl reset-failed dropbear 2>/dev/null || true
        systemctl restart dropbear || true
        sleep 1
        if dropbear_listening; then
            echo "dropbear listening on :22"
            break
        fi
        echo "dropbear not ready, retry $i"
        pkill -x sshd 2>/dev/null || true
        i=$((i + 1))
    done

    if ! dropbear_listening; then
        echo "dropbear still failed, putting openssh back so you are not locked out"
        systemctl unmask ssh 2>/dev/null || true
        apt_install openssh-server
        systemctl enable --now ssh
        echo "openssh-server restored; fix dropbear manually later"
        exit 1
    fi

    systemctl mask ssh 2>/dev/null || true
    systemctl mask sshd 2>/dev/null || true
    echo "dropbear enabled, openssh-server purged"
else
    apt_install openssh-server openssh-client
    systemctl stop dropbear 2>/dev/null || true
    systemctl disable dropbear 2>/dev/null || true
    systemctl unmask ssh 2>/dev/null || true
    service_enable ssh
    echo "openssh-server enabled"
fi
