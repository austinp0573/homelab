#!/bin/sh

set -eu
set -o pipefail

ARCH="arm64"
VERSION="5.2.2"
RELEASE="lego_v${VERSION}_linux_${ARCH}.tar.gz"
URL="https://github.com/go-acme/lego/releases/download/v${VERSION}/${RELEASE}"

sudo groupadd -g 991 -f lego

if ! id -u lego >/dev/null 2>&1; then
    sudo useradd -u 991 -g lego -c "Lego ACME Client" -d /etc/lego -s /usr/sbin/nologin lego
fi

curl -LO "$URL"

tar xzf "$RELEASE" lego
sudo mv lego /usr/local/bin/
rm "$RELEASE"

sudo mkdir -p /etc/lego/certificates /etc/lego/accounts
sudo chown -R lego:lego /etc/lego
sudo chmod 750 /etc/lego /etc/lego/certificates /etc/lego/accounts

