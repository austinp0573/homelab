#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for script in "$ROOT_DIR"/setup.sh "$ROOT_DIR"/pack.sh \
    "$ROOT_DIR"/core/*.sh "$ROOT_DIR"/optional/*.sh "$ROOT_DIR"/tests/*.sh; do
    bash -n "$script"
done

for profile in cloud-openssh cloud-dropbear proxmox-openssh proxmox-dropbear; do
    test -f "$ROOT_DIR/profiles/$profile.env"
done

grep -q 'PROFILE=cloud-openssh' "$ROOT_DIR/.env.example"
grep -q 'AUTO_SECURITY_UPDATES=y' "$ROOT_DIR/.env.example"
grep -q -- '--no-autoremove' "$ROOT_DIR/lib/common.sh"
grep -q 'apt-daily-upgrade.timer' "$ROOT_DIR/core/75-unattended-upgrades.sh"

echo "smoke checks passed"
