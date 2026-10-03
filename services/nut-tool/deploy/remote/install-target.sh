#!/bin/sh
set -eu

usage() {
    cat >&2 <<'USAGE'
Usage:
  sudo ./install-target.sh /path/to/id_ed25519.pub

Run this on each SSH shutdown target. It auto-selects the systemd helper when
systemd-run is available; otherwise it installs the Alpine/BusyBox helper.
USAGE
    exit 2
}

[ "$#" -eq 1 ] || usage
PUBKEY_FILE=$1
[ -f "$PUBKEY_FILE" ] || { echo "missing public key: $PUBKEY_FILE" >&2; exit 1; }
command -v sudo >/dev/null 2>&1 || {
    echo "sudo is required on the target (Debian: apt install sudo; Alpine: apk add sudo)" >&2
    exit 1
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GATE="$SCRIPT_DIR/nut-tool-ssh-gate"
SUDOERS="$SCRIPT_DIR/nut-tool.sudoers"

if command -v systemd-run >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    POWEROFF="$SCRIPT_DIR/nut-tool-remote-poweroff-systemd"
else
    POWEROFF="$SCRIPT_DIR/nut-tool-remote-poweroff-alpine"
fi

for f in "$GATE" "$SUDOERS" "$POWEROFF"; do
    [ -f "$f" ] || { echo "missing deployment file: $f" >&2; exit 1; }
done

if ! id -u ups-shutdown >/dev/null 2>&1; then
    if command -v useradd >/dev/null 2>&1; then
        if ! grep -q '^ups-shutdown:' /etc/group; then
            groupadd --system ups-shutdown
        fi
        useradd \
            --system \
            --gid ups-shutdown \
            --create-home \
            --home-dir /var/lib/ups-shutdown \
            --shell /bin/sh \
            ups-shutdown
    elif command -v adduser >/dev/null 2>&1; then
        adduser -S -D -h /var/lib/ups-shutdown -s /bin/sh ups-shutdown
    else
        echo "no supported user creation command found" >&2
        exit 1
    fi
fi

HOME_DIR=$(awk -F: '$1 == "ups-shutdown" { print $6 }' /etc/passwd)
[ -n "$HOME_DIR" ] || { echo "could not determine ups-shutdown home" >&2; exit 1; }

install -o root -g root -m 0755 "$GATE" /usr/local/sbin/nut-tool-ssh-gate
install -o root -g root -m 0755 "$POWEROFF" /usr/local/sbin/nut-tool-remote-poweroff
install -o root -g root -m 0440 "$SUDOERS" /etc/sudoers.d/nut-tool

if command -v visudo >/dev/null 2>&1; then
    visudo -cf /etc/sudoers.d/nut-tool >/dev/null
fi

install -d -o ups-shutdown -g ups-shutdown -m 0700 "$HOME_DIR/.ssh"
AUTH_KEYS="$HOME_DIR/.ssh/authorized_keys"
touch "$AUTH_KEYS"
chown ups-shutdown:ups-shutdown "$AUTH_KEYS"
chmod 0600 "$AUTH_KEYS"

PUBKEY=$(cat "$PUBKEY_FILE")
case "$PUBKEY" in
    ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-*\ *) ;;
    *) echo "public key does not look like an OpenSSH public key" >&2; exit 1 ;;
esac

LINE="restrict,command=\"/usr/local/sbin/nut-tool-ssh-gate\" $PUBKEY"
if ! grep -Fqx "$LINE" "$AUTH_KEYS"; then
    printf '%s\n' "$LINE" >> "$AUTH_KEYS"
fi

chown ups-shutdown:ups-shutdown "$AUTH_KEYS"
chmod 0600 "$AUTH_KEYS"

echo "target installed"
echo "forced SSH user: ups-shutdown"
echo "poweroff helper: $POWEROFF"
