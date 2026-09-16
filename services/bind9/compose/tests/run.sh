#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
export CONTAINERD_NAMESPACE=${CONTAINERD_NAMESPACE:-tusko-dns-validation}
bash "$root/scripts/build-image.sh"
exec bash "$root/tests/check-ha.sh"
