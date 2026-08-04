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
SWAPFILE_SIZE="${SWAPFILE_SIZE:-1G}"

# higher number = preferred by kernel
ZRAM_PRI=100
SWAPFILE_PRI=10

if is_yes "$ZRAM"; then
    apt_install zram-tools
    cat > /etc/default/zramswap << EOF
ALGO=$ZRAM_ALGORITHM
PERCENT=$ZRAM_SIZE_PERCENT
PRIORITY=$ZRAM_PRI
EOF
    service_enable zramswap
    echo "zram on percent=$ZRAM_SIZE_PERCENT algo=$ZRAM_ALGORITHM pri=$ZRAM_PRI"
else
    service_disable zramswap 2>/dev/null || true
    echo "zram off"
fi

if is_yes "$SWAPFILE"; then
    if [ ! -f "$SWAPFILE_PATH" ]; then
        echo "creating $SWAPFILE_PATH size $SWAPFILE_SIZE"
        fallocate -l "$SWAPFILE_SIZE" "$SWAPFILE_PATH"
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
