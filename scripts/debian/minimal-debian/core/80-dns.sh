#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "dns"

MANAGE_DNS="${MANAGE_DNS:-y}"
DNS_SERVERS="${DNS_SERVERS:-1.1.1.1 1.0.0.1}"

if is_no "$MANAGE_DNS"; then
    echo "MANAGE_DNS=n, skipping"
    exit 0
fi

# stop resolved from rewriting resolv.conf
service_disable systemd-resolved 2>/dev/null || true
if [ -L /etc/resolv.conf ] || [ -f /etc/resolv.conf ]; then
    rm -f /etc/resolv.conf
fi

{
    echo "# written by minimal-debian"
    for ns in $DNS_SERVERS; do
        echo "nameserver $ns"
    done
} > /etc/resolv.conf
chmod 644 /etc/resolv.conf

echo "resolv.conf -> $DNS_SERVERS"
