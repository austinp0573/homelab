#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

# Set NERDCTL_SHA256 from the release checksums before running this script.
VERSION="${NERDCTL_VERSION:-2.3.4}"
ARCH="${NERDCTL_ARCH:-${ARCH:-amd64}}"
NERDCTL_SHA256="${NERDCTL_SHA256:-}"

echo "nerdctl-full $VERSION $ARCH"

if [ -z "$NERDCTL_SHA256" ]; then
    echo "NERDCTL_SHA256 must be set"
    exit 1
fi

apt_install curl ca-certificates

url="https://github.com/containerd/nerdctl/releases/download/v${VERSION}/nerdctl-full-${VERSION}-linux-${ARCH}.tar.gz"
tmp="/tmp/nerdctl-full-${VERSION}-linux-${ARCH}.tar.gz"

echo "downloading $url"
curl -fsSL -o "$tmp" "$url"
printf '%s  %s\n' "$NERDCTL_SHA256" "$tmp" | sha256sum -c -

echo "extracting to /usr/local"
tar -C /usr/local -xzf "$tmp"
rm -f "$tmp"

systemctl daemon-reload

# units shipped under /usr/local/lib/systemd/system
for svc in containerd buildkit; do
    if [ -f "/usr/local/lib/systemd/system/${svc}.service" ] || \
       [ -f "/etc/systemd/system/${svc}.service" ] || \
       systemctl list-unit-files "${svc}.service" 2>/dev/null | grep -q "${svc}.service"; then
        systemctl enable --now "$svc"
        echo "enabled $svc"
    else
        echo "unit not found for $svc (check tarball layout)"
    fi
done

command -v nerdctl >/dev/null
command -v containerd >/dev/null
echo "nerdctl-full installed"
