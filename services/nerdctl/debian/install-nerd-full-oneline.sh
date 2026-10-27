#!/bin/sh

set -e

curl -fsSL https://github.com/containerd/nerdctl/releases/download/v2.3.5/nerdctl-full-2.3.5-linux-arm64.tar.gz | tar -C /usr/local -xz

systemctl daemon-reload

systemctl restart containerd.service
systemctl restart buildkit.service
