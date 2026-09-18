#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "unattended upgrades extra packages"

cat > /etc/apt/apt.conf.d/51unattended-upgrades-extra << 'EOF'
Unattended-Upgrade::Package-Blacklist {
};
EOF

echo "unattended upgrades extra configured"
