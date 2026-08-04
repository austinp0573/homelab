#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "rsyslog"

apt_install rsyslog
service_enable rsyslog
echo "rsyslog enabled"
