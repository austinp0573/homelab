#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "purge cloud-init"

PURGE_CLOUD_INIT="${PURGE_CLOUD_INIT:-y}"
MANAGE_NETWORK="${MANAGE_NETWORK:-n}"

if is_no "$PURGE_CLOUD_INIT"; then
    echo "PURGE_CLOUD_INIT=n, skipping"
    exit 0
fi

# Keep an existing provider network stack unless an explicit networkd
# migration was requested.
if pkg_installed netplan.io; then
    apt-mark manual netplan.io 2>/dev/null || true
    apt-mark manual netplan-generator 2>/dev/null || true
fi
apt-mark manual iproute2 2>/dev/null || true

if is_yes "$MANAGE_NETWORK"; then
    iface="$(ip route show default 2>/dev/null | awk 'NR == 1 {print $5}')"
    if [ -z "$iface" ]; then
        for path in /sys/class/net/*; do
            name="$(basename "$path")"
            [ "$name" = "lo" ] && continue
            iface="$name"
            break
        done
    fi

    if [ -z "$iface" ]; then
        echo "no network interface found for networkd"
        exit 1
    fi

    mac="$(cat "/sys/class/net/$iface/address" 2>/dev/null || true)"
    ensure_dir /etc/systemd/network
    {
        echo "[Match]"
        echo "Name=$iface"
        if [ -n "$mac" ] && [ "$mac" != "00:00:00:00:00:00" ]; then
            echo "MACAddress=$mac"
        fi
        echo
        echo "[Network]"
        echo "DHCP=yes"
    } > /etc/systemd/network/10-minimal-debian.network
    echo "wrote /etc/systemd/network/10-minimal-debian.network for $iface"
    systemctl enable systemd-networkd 2>/dev/null || true
    systemctl restart systemd-networkd 2>/dev/null || true
else
    echo "MANAGE_NETWORK=n, keeping current network configuration"
fi

apt_purge cloud-init cloud-init-base cloud-utils cloud-guest-utils \
    cloud-initramfs-growroot cloud-initramfs-rescuevol

rm -rf /etc/cloud /var/lib/cloud

if is_yes "$MANAGE_NETWORK" && command -v netplan >/dev/null 2>&1; then
    netplan generate 2>/dev/null || true
    netplan apply 2>/dev/null || true
fi

echo "cloud-init purged"
