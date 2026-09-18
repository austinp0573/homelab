#!/bin/sh
# description: install speedtest-go if missing

set -e

RELEASE="1.7.10"

arch_raw=$(uname -m)
case "$arch_raw" in
    aarch64|arm64)
        SPEED_ARCH="arm64"
        ;;
    armv7l|armv6l|armhf)
        SPEED_ARCH="armv7"
        ;;
    x86_64)
        SPEED_ARCH="x86_64"
        ;;
    *)
        SPEED_ARCH="arm64"
        ;;
esac

ARCHIVE="speedtest-go_${RELEASE}_Linux_${SPEED_ARCH}.tar.gz"
URL="https://github.com/showwin/speedtest-go/releases/download/v${RELEASE}/${ARCHIVE}"

if command -v speedtest > /dev/null 2>&1; then
    echo "speedtest is already installed"
    speedtest --version
    exit 0
fi

for cmd in wget tar; do
    command -v $cmd > /dev/null 2>&1 || { echo "error: $cmd is required but not installed"; exit 1; }
done

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cd "$tmpdir"

echo "downloading speedtest-go v${RELEASE} for ${SPEED_ARCH}"
wget -q "$URL"

echo "extracting"
tar -xf "$ARCHIVE"

if [ ! -f speedtest-go ]; then
    echo "error: speedtest-go binary not found after extraction"
    exit 1
fi

echo "installing to /usr/local/bin/speedtest"
mv speedtest-go /usr/local/bin/speedtest

cd /
echo "verifying"
which speedtest
speedtest --version
echo "done"
