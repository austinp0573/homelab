#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "fail2ban"

apt_install fail2ban
service_enable fail2ban
echo "fail2ban enabled"
