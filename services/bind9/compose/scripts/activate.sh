#!/usr/bin/env bash
set -euo pipefail
[[ $EUID == 0 ]] || { printf 'run activation as root\n' >&2; exit 1; }
bundle=$(cd -- "${1:?usage: activate.sh release-directory}" && pwd -P)
[[ $bundle == /opt/dns/releases/* ]] || { printf 'release must be beneath /opt/dns/releases\n' >&2; exit 1; }
# shellcheck disable=SC1091
source "$bundle/.env"
export CONTAINERD_NAMESPACE=dns
export DATA_DIR=/opt/dns/data
role=$(< "$bundle/role")
if [[ -f /opt/dns/current/role ]]; then
    [[ $(< /opt/dns/current/role) == "$role" ]] || { printf 'refusing an in-place node role change\n' >&2; exit 1; }
fi
if [[ ${BUILD_IMAGE:-1} == 1 ]]; then
    nerdctl --namespace dns build --progress plain --tag "$BIND_IMAGE" "$bundle"
else
    nerdctl --namespace dns pull "$BIND_IMAGE"
fi
bash "$bundle/scripts/validate.sh" "$bundle"
bash "$bundle/scripts/prepare.sh" "$bundle"
nerdctl --namespace dns compose -p tusko-dns --env-file "$bundle/.env" -f "$bundle/compose.yaml" config --quiet
nerdctl --namespace dns compose -p tusko-dns --env-file "$bundle/.env" -f "$bundle/compose.yaml" up -d --force-recreate --pull never
deadline=$((SECONDS + 60))
until bash "$bundle/scripts/probe.sh" "$NODE_IPV4"; do
    (( SECONDS < deadline )) || { printf 'activation probes failed; current link was not changed; inspect containers and restore the previous release\n' >&2; exit 1; }
done
ln -sfn "$bundle" /opt/dns/current.next
mv -Tf /opt/dns/current.next /opt/dns/current
printf 'activated %s\n' "$bundle"
