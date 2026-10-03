#!/bin/sh
set -eu

usage() {
    cat >&2 <<'USAGE'
Usage:
  sudo ./install-controller.sh BINARY CONFIG PRIVATE_KEY KNOWN_HOSTS

Example:
  sudo ./install-controller.sh \
    ./target/x86_64-unknown-linux-musl/release/nut-tool \
    ./config.toml ./id_ed25519 ./known_hosts
USAGE
    exit 2
}

[ "$#" -eq 4 ] || usage

BINARY=$1
CONFIG=$2
PRIVATE_KEY=$3
KNOWN_HOSTS=$4
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
UNIT="$SCRIPT_DIR/nut-tool.service"

for f in "$BINARY" "$CONFIG" "$PRIVATE_KEY" "$KNOWN_HOSTS" "$UNIT"; do
    [ -f "$f" ] || { echo "missing file: $f" >&2; exit 1; }
done

if ! getent group nut-tool >/dev/null 2>&1; then
    groupadd --system nut-tool
fi

if ! id -u nut-tool >/dev/null 2>&1; then
    useradd \
        --system \
        --gid nut-tool \
        --home-dir /nonexistent \
        --shell /usr/sbin/nologin \
        nut-tool
fi

install -o root -g root -m 0755 "$BINARY" /usr/local/bin/nut-tool
install -d -o root -g nut-tool -m 0750 /etc/nut-tool
install -o root -g nut-tool -m 0640 "$CONFIG" /etc/nut-tool/config.toml
install -o nut-tool -g nut-tool -m 0400 "$PRIVATE_KEY" /etc/nut-tool/id_ed25519
install -o root -g nut-tool -m 0640 "$KNOWN_HOSTS" /etc/nut-tool/known_hosts
install -o root -g root -m 0644 "$UNIT" /etc/systemd/system/nut-tool.service

# Validate as the actual service account before enabling the daemon.
runuser -u nut-tool -- \
    /usr/local/bin/nut-tool \
    --config /etc/nut-tool/config.toml \
    check

systemctl daemon-reload
systemctl enable --now nut-tool.service

echo "nut-tool installed and started"
echo "logs: journalctl -u nut-tool -f"
