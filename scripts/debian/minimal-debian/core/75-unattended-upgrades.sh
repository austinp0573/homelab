#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "security updates"

AUTO_SECURITY_UPDATES="${AUTO_SECURITY_UPDATES:-y}"

if is_no "$AUTO_SECURITY_UPDATES"; then
    echo "AUTO_SECURITY_UPDATES=n, skipping"
    exit 0
fi

apt_install unattended-upgrades

cat > /etc/apt/apt.conf.d/50unattended-upgrades-minimal << 'EOF'
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

systemctl enable --now apt-daily.timer apt-daily-upgrade.timer
service_enable unattended-upgrades
echo "security updates enabled"
