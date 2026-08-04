#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "purge cruft"

# leaf junk only. do not touch python3, netplan, iproute2, or dhcp clients.
apt_purge \
    ufw \
    snapd \
    popularity-contest \
    bluetooth bluez \
    cups cups-daemon cups-common \
    avahi-daemon avahi-utils \
    modemmanager \
    network-manager \
    landscape-common \
    needrestart \
    packagekit \
    plymouth plymouth-label \
    reportbug \
    apt-listchanges

# snap leftovers
rm -rf /snap /var/snap /var/lib/snapd 2>/dev/null || true

# make sure networking tooling survived any autoremove
apt_install iproute2 procps iputils-ping
if ! pkg_installed netplan.io && [ -d /etc/netplan ]; then
    echo "netplan.io missing but /etc/netplan exists, reinstalling"
    apt_install netplan.io
fi

echo "cruft purge done"
