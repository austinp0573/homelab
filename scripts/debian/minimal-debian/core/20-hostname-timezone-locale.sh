#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "hostname timezone locale"

HOSTNAME="${HOSTNAME:-}"
TIMEZONE="${TIMEZONE:-America/Chicago}"
LOCALE="${LOCALE:-en_US.UTF-8}"

if [ -n "$HOSTNAME" ]; then
    echo "$HOSTNAME" > /etc/hostname
    hostnamectl set-hostname "$HOSTNAME" 2>/dev/null || hostname "$HOSTNAME"
    if grep -qE '^127\.0\.1\.1' /etc/hosts; then
        sed -i "s/^127\\.0\\.1\\.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
    else
        echo "127.0.1.1	$HOSTNAME" >> /etc/hosts
    fi
    echo "hostname=$HOSTNAME"
fi

if [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
    echo "timezone not found: $TIMEZONE"
    exit 1
fi
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
echo "$TIMEZONE" > /etc/timezone
echo "timezone=$TIMEZONE"

apt_install locales
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG="$LOCALE" LC_ALL="$LOCALE"
echo "locale=$LOCALE"
