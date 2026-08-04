#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "trim services"

# disable if present; ignore failures
for svc in \
    motd-news.timer \
    motd-news.service \
    bluetooth.service \
    cups.service \
    cups-browsed.service \
    avahi-daemon.service \
    ModemManager.service \
    PackageKit.service \
    pstore.service
do
    if systemctl list-unit-files "$svc" 2>/dev/null | grep -q "$svc"; then
        echo "disabling $svc"
        service_disable "$svc"
    fi
done

echo "services trimmed"
