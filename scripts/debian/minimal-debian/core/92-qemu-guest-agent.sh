#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "qemu guest agent"

QEMU_GUEST_AGENT="${QEMU_GUEST_AGENT:-n}"

if is_yes "$QEMU_GUEST_AGENT"; then
    apt_install qemu-guest-agent
    service_enable qemu-guest-agent
    echo "qemu-guest-agent enabled"
else
    service_disable qemu-guest-agent 2>/dev/null || true
    apt_purge qemu-guest-agent
    echo "qemu-guest-agent purged"
fi
