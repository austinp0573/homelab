#!/bin/sh
set -eu
set -o pipefail

ARCH="amd64"
VERSION="2.3.4"
RELEASE="nerdctl-full-${VERSION}-linux-${ARCH}.tar.gz"
URL="https://github.com/containerd/nerdctl/releases/download/v${VERSION}/${RELEASE}"

cd /tmp

printf "\nDownloading %s...\n" "${RELEASE}"
curl -LO "${URL}"
printf "\n%s downloaded successfully.\n" "${RELEASE}"

printf "\nExtracting binaries and assets to /usr/local...\n"
sudo tar -C /usr/local -xzf "${RELEASE}"

# Link systemd service files to the standard systemd directory
printf "\nLinking systemd service units...\n"
sudo ln -sf /usr/local/lib/systemd/system/containerd.service /lib/systemd/system/
sudo ln -sf /usr/local/lib/systemd/system/buildkit.service /lib/systemd/system/

printf "\nReloading daemons and enabling services...\n"
sudo systemctl daemon-reload
sudo systemctl enable --now containerd.service
sudo systemctl enable --now buildkit.service

printf "\nInstallation completed successfully.\n"