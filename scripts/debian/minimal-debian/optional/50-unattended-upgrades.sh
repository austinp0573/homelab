#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "unattended-upgrades"

apt_install unattended-upgrades apt-listchanges

cat > /etc/apt/apt.conf.d/50unattended-upgrades-minimal << 'EOF'
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
EOF

echo 'APT::Periodic::Update-Package-Lists "1";' > /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades

service_enable unattended-upgrades
echo "unattended-upgrades enabled (security)"
