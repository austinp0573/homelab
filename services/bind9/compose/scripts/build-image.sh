#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
image=${1:-tusko-bind:local}
exec "${NERDCTL:-nerdctl}" --namespace "${CONTAINERD_NAMESPACE:-dns}" build \
    --progress plain --tag "$image" "$root"
