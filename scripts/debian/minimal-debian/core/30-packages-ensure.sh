#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "ensure packages"

# always keep these (lean images often miss them; autoremove must not strand us)
apt_install iproute2 procps iputils-ping

ENSURE_PACKAGES="${ENSURE_PACKAGES:-curl git fastfetch}"

# shellcheck disable=SC2086
apt_install $ENSURE_PACKAGES

echo "packages ok: iproute2 procps iputils-ping $ENSURE_PACKAGES"
