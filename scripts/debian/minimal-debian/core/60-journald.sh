#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "journald"

JOURNAL_TO_RAM="${JOURNAL_TO_RAM:-n}"
JOURNAL_SYSTEM_MAX_USE="${JOURNAL_SYSTEM_MAX_USE:-50M}"
KEEP_RSYSLOG="${KEEP_RSYSLOG:-n}"

ensure_dir /etc/systemd/journald.conf.d

if is_yes "$JOURNAL_TO_RAM"; then
    cat > /etc/systemd/journald.conf.d/99-minimal.conf << 'EOF'
[Journal]
Storage=volatile
EOF
    echo "journal: volatile (ram)"
else
    cat > /etc/systemd/journald.conf.d/99-minimal.conf << EOF
[Journal]
Storage=persistent
SystemMaxUse=$JOURNAL_SYSTEM_MAX_USE
EOF
    ensure_dir /var/log/journal
    echo "journal: persistent max $JOURNAL_SYSTEM_MAX_USE"
fi

systemctl restart systemd-journald

if is_no "$KEEP_RSYSLOG"; then
    apt_purge rsyslog
fi
