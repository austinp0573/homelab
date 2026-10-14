#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

VERSION="${BAT_VERSION:-0.26.1}"
ARCH="${BAT_ARCH:-${ARCH:-amd64}}"

echo "bat $VERSION $ARCH"

apt_install curl ca-certificates

url="https://github.com/sharkdp/bat/releases/download/v${VERSION}/bat_${VERSION}_${ARCH}.deb"
tmp="/tmp/bat_${VERSION}_${ARCH}.deb"

echo "downloading $url"
curl -fsSL -o "$tmp" "$url"

echo "installing $tmp"
DEBIAN_FRONTEND=noninteractive apt-get install -y "$tmp"
rm -f "$tmp"

command -v bat >/dev/null
echo "bat installed: $(bat --version)"
