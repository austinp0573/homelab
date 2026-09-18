#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "preflight"

if [ ! -f /etc/os-release ]; then
    echo "no /etc/os-release"
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

if [ "${ID:-}" != "debian" ] && [ "${ID:-}" != "raspbian" ] && ! [[ "${ID_LIKE:-}" =~ debian ]]; then
    echo "this script is for Raspberry Pi OS / Debian (ID=$ID)"
    exit 1
fi

if [ -n "${ARCH:-}" ]; then
    have="$(dpkg --print-architecture)"
    if [ "$have" != "$ARCH" ]; then
        echo "warning: configured ARCH=$ARCH but dpkg arch is $have"
    fi
fi

if [ -z "${ADMIN_USER:-}" ]; then
    echo ""
    echo ""
    echo "ADMIN USER MUST BE SET!"
    echo "SET IT AND RERUN"
    echo ""
    exit 1
fi

admin_keys="${ADMIN_SSH_KEYS:-}"
if is_yes "${SAME_SSH_KEYS:-n}"; then
    admin_keys="${ROOT_SSH_KEYS:-}"
fi

if [ -z "${ADMIN_PASSWORD:-}" ] && [ -z "$admin_keys" ]; then
    echo "set ADMIN_PASSWORD or admin SSH keys before running setup"
    exit 1
fi

echo "preflight ok"
