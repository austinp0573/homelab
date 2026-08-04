#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "time sync"

USE_CHRONY="${USE_CHRONY:-n}"

if is_yes "$USE_CHRONY"; then
    apt_install chrony
    service_disable systemd-timesyncd
    service_enable chrony
    echo "chrony enabled"
else
    service_disable chrony 2>/dev/null || true
    apt_purge chrony 2>/dev/null || true
    # timesyncd is part of systemd
    systemctl unmask systemd-timesyncd 2>/dev/null || true
    service_enable systemd-timesyncd
    echo "systemd-timesyncd enabled"
fi
