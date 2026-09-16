#!/usr/bin/env bash
set -euo pipefail

[[ $EUID == 0 ]] || { printf 'run prepare.sh as root\n' >&2; exit 1; }
bundle=$(cd -- "${1:?usage: prepare.sh rendered-directory [data-directory]}" && pwd -P)
data=${2:-/opt/dns/data}
[[ $data == /* && $data != / && $data != */../* ]] || { printf 'use an absolute data directory\n' >&2; exit 1; }
role=$(< "$bundle/role")
[[ $role == primary || $role == secondary ]] || { printf 'invalid role\n' >&2; exit 1; }
[[ -s $bundle/secrets/transfer.key ]] || { printf 'missing transfer.key\n' >&2; exit 1; }
if [[ $role == primary ]]; then
    [[ -s $bundle/secrets/externaldns.key ]] || { printf 'missing externaldns.key\n' >&2; exit 1; }
fi

for directory in auth-cache auth-lib resolver-cache resolver-lib; do
    install -d -m 0750 -o 10001 -g 10001 "$data/$directory"
done
chmod 0755 "$bundle/auth" "$bundle/resolver" "$bundle/zones"
find "$bundle/auth" "$bundle/resolver" "$bundle/zones" -type f -exec chmod 0644 {} +
chown root:10001 "$bundle/secrets"
chmod 0750 "$bundle/secrets"
find "$bundle/secrets" -type f -exec chown root:10001 {} + -exec chmod 0640 {} +
if [[ $role == primary && ! -e $data/auth-lib/k8s.tusko.org.zone ]]; then
    [[ ! -e $data/auth-lib/k8s.tusko.org.zone.jnl ]] || { printf 'journal exists without zone; restore the zone before starting\n' >&2; exit 1; }
    install -m 0640 -o 10001 -g 10001 "$bundle/seed/k8s.tusko.org.zone" "$data/auth-lib/k8s.tusko.org.zone"
fi
printf 'prepared %s with persistent data in %s\n' "$role" "$data"
