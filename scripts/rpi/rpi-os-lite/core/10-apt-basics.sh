#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "apt basics"

apt_update_once

APT_INSTALL_RECOMMENDS="${APT_INSTALL_RECOMMENDS:-n}"

if is_no "$APT_INSTALL_RECOMMENDS"; then
    cat > /etc/apt/apt.conf.d/99no-recommends << 'EOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF
    echo "recommends disabled"
else
    rm -f /etc/apt/apt.conf.d/99no-recommends
    echo "recommends left alone"
fi
