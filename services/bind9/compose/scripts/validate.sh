#!/usr/bin/env bash
set -euo pipefail

bundle=$(cd -- "${1:?usage: validate.sh rendered-directory}" && pwd -P)
# shellcheck disable=SC1091
source "$bundle/.env"
image=${VALIDATION_IMAGE:-$BIND_IMAGE}
nerdctl_bin=${NERDCTL:-nerdctl}
namespace=${CONTAINERD_NAMESPACE:-dns}
[[ -s $bundle/secrets/transfer.key ]] || { printf 'missing transfer key\n' >&2; exit 1; }

for service in auth resolver; do
    "$nerdctl_bin" --namespace "$namespace" run --rm --pull missing --net none \
        --read-only --user 0:0 --entrypoint named-checkconf \
        --volume "$bundle/$service:/etc/bind:ro" \
        --volume "$bundle/zones:/zones:ro" \
        --volume "$bundle/seed:/var/lib/bind:ro" \
        --volume "$bundle/secrets:/run/secrets:ro" \
        "$image" -z /etc/bind/named.conf
done
printf 'BIND configuration and primary zone validation passed: %s\n' "$bundle"
