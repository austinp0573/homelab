#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "ensure packages"

ENSURE_PACKAGES="${ENSURE_PACKAGES:-}"

if [ -n "$ENSURE_PACKAGES" ]; then
    # shellcheck disable=SC2086
    apt_install $ENSURE_PACKAGES
    echo "packages installed: $ENSURE_PACKAGES"
else
    echo "no additional packages declared in ENSURE_PACKAGES"
fi
