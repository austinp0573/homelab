#!/bin/sh

set -eou pipefail

ARCH="amd64"
VERSION="2.3.3"
RELEASE="nerdctl-${VERSION}-linux-${ARCH}.tar.gz"
URL="https://github.com/containerd/nerdctl/releases/download/v${VERSION}/${RELEASE}"

cd /tmp

wget ${URL}

tar -C /usr/local/bin -xzf /tmp/${RELEASE} nerdctl

rm /tmp/${RELEASE}

chmod +x /usr/local/bin/nerdctl

printf "\nif you do it this way you need the following packages:\n"
printf " ca-certificates\n"
printf " containerd\n"
printf " cni-plugins\n"
printf " iptables\n"
printf " buildkit\n"
printf " so:libc.musl-x86.so.1\n\n"
printf "run the following"
printf "\n-----------------\n"
printf "apk add ca-certificates containerd cni-plugins buildkit iptables\n"
printf "\nWHICH I AM NOW DOING!!!!!!\n"

apk add ca-certificates containerd cni-plugins buildkit iptables

mkdir -p /etc/buildkit

cat << 'EOF' > /etc/buildkit/buildkitd.toml
[worker.oci]
  enabled = false

[worker.containerd]
  enabled = true
  namespace = "default"
EOF

rc-update add containerd default
rc-update add buildkitd default
rc-service containerd start
rc-service buildkitd start
