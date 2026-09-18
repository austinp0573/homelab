#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "vim-nox"

apt_install vim-nox
update-alternatives --set editor /usr/bin/vim.nox 2>/dev/null || true
echo "vim-nox installed and set as default editor"
