#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "zram / swap"

ZRAM="${ZRAM:-y}"
ZRAM_SIZE_PERCENT="${ZRAM_SIZE_PERCENT:-50}"
ZRAM_ALGORITHM="${ZRAM_ALGORITHM:-lz4}"
SWAPFILE="${SWAPFILE:-y}"
SWAPFILE_PATH="${SWAPFILE_PATH:-/swapfile}"
SWAPFILE_SIZE="${SWAPFILE_SIZE:-2G}"

# higher number = preferred by kernel
ZRAM_PRI=100
SWAPFILE_PRI=10

# On Raspberry Pi OS, disable dphys-swapfile if present to avoid conflicting swap management
if pkg_installed dphys-swapfile; then
    echo "disabling dphys-swapfile in favor of zram/swapfile"
    service_disable dphys-swapfile || true
fi

if is_yes "$ZRAM"; then
    echo "configuring systemd zram-generator override"
    mkdir -p /etc/systemd/zram-generator.conf.d

    cat > /etc/systemd/zram-generator.conf.d/20-rpi-swap-zram0-ctrl.conf << EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = $ZRAM_PRI
EOF

    # Stop and disable legacy zramswap service if installed to prevent conflicts
    if pkg_installed zram-tools || systemctl list-unit-files zramswap.service 2>/dev/null | grep -q zramswap; then
        service_disable zramswap 2>/dev/null || true
    fi

    # Reload systemd and trigger generator
    swapoff /dev/zram0 2>/dev/null || true
    systemctl daemon-reload
    systemctl restart systemd-zram-setup@zram0 2>/dev/null || systemctl start systemd-zram-setup@zram0 2>/dev/null || true
    echo "zram configured via systemd-zram-generator (50% RAM, pri=$ZRAM_PRI)"
else
    mkdir -p /etc/systemd/zram-generator.conf.d
    ln -sf /dev/null /etc/systemd/zram-generator.conf.d/20-rpi-swap-zram0-ctrl.conf
    swapoff /dev/zram0 2>/dev/null || true
    systemctl daemon-reload
    echo "zram disabled"
fi

if is_yes "$SWAPFILE"; then
    if [ ! -f "$SWAPFILE_PATH" ]; then
        echo "creating BTRFS-compliant NOCOW $SWAPFILE_PATH size $SWAPFILE_SIZE"
        truncate -s 0 "$SWAPFILE_PATH" 2>/dev/null || true
        chattr +C "$SWAPFILE_PATH" 2>/dev/null || true
        fallocate -l "$SWAPFILE_SIZE" "$SWAPFILE_PATH" || dd if=/dev/zero of="$SWAPFILE_PATH" bs=1M count=2048 status=progress
        chmod 600 "$SWAPFILE_PATH"
        mkswap "$SWAPFILE_PATH"
    fi
    if ! grep -q "^$SWAPFILE_PATH " /etc/fstab 2>/dev/null; then
        echo "$SWAPFILE_PATH none swap sw,pri=$SWAPFILE_PRI 0 0" >> /etc/fstab
    else
        sed -i "s|^$SWAPFILE_PATH .*|$SWAPFILE_PATH none swap sw,pri=$SWAPFILE_PRI 0 0|" /etc/fstab
    fi
    swapon -p "$SWAPFILE_PRI" "$SWAPFILE_PATH" 2>/dev/null || swapon "$SWAPFILE_PATH" 2>/dev/null || true
    echo "swapfile on $SWAPFILE_PATH pri=$SWAPFILE_PRI"
else
    if [ -f "$SWAPFILE_PATH" ]; then
        swapoff "$SWAPFILE_PATH" 2>/dev/null || true
    fi
    if grep -q "^$SWAPFILE_PATH " /etc/fstab 2>/dev/null; then
        sed -i "\|^$SWAPFILE_PATH |d" /etc/fstab
    fi
    echo "swapfile off"
fi
