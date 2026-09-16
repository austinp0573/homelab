#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
role=${1:?usage: render.sh primary|secondary [env-file]}
env_file=${2:-$root/.env}
[[ $role == primary || $role == secondary ]] || { printf 'invalid role\n' >&2; exit 1; }
[[ -f $env_file ]] || { printf 'missing environment file: %s\n' "$env_file" >&2; exit 1; }
set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

valid_ipv4() {
    local address=$1
    [[ $address =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    awk -F . '{ for (part = 1; part <= 4; part++) if ($part > 255 || $part ~ /^0[0-9]/) exit 1 }' <<< "$address"
}

valid_ipv4 "${DNS_PRIMARY_IPV4:-}" && valid_ipv4 "${DNS_SECONDARY_IPV4:-}" || {
    printf 'replace both DNS node IPv4 placeholders with valid addresses\n' >&2
    exit 1
}
[[ $DNS_PRIMARY_IPV4 != "$DNS_SECONDARY_IPV4" ]] || { printf 'node addresses must differ\n' >&2; exit 1; }
[[ ${BIND_IMAGE:-} =~ ^[a-zA-Z0-9][a-zA-Z0-9./:@_-]+$ ]] || { printf 'invalid BIND_IMAGE\n' >&2; exit 1; }
[[ ${BUILD_IMAGE:-1} == 0 || ${BUILD_IMAGE:-1} == 1 ]] || { printf 'BUILD_IMAGE must be 0 or 1\n' >&2; exit 1; }
command -v envsubst >/dev/null

if [[ $role == primary ]]; then NODE_IPV4=$DNS_PRIMARY_IPV4; else NODE_IPV4=$DNS_SECONDARY_IPV4; fi
export NODE_IPV4
output=${OUTPUT_ROOT:-$root/build}/$role
mkdir -p "$output/auth" "$output/resolver" "$output/zones"
variables='${DNS_PRIMARY_IPV4} ${DNS_SECONDARY_IPV4} ${NODE_IPV4}'
envsubst "$variables" < "$root/config/authoritative.conf.template" > "$output/auth/named.conf"
envsubst "$variables" < "$root/config/clients.conf.template" > "$output/auth/clients.conf"
cp "$output/auth/clients.conf" "$output/resolver/clients.conf"
: > "$output/auth/zones.conf"
: > "$output/resolver/forward-zones.conf"
: > "$output/resolver/validation-exceptions.conf"
declare -A seen_zones=()

while read -r zone filename extra || [[ -n $zone ]]; do
    [[ -z $zone || $zone == \#* ]] && continue
    [[ $zone =~ ^[a-z0-9][a-z0-9.-]+$ && $filename =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]+$ && -z $extra ]] || {
        printf 'invalid static zone entry: %s\n' "$zone" >&2; exit 1;
    }
    [[ -z ${seen_zones[$zone]:-} && $zone != k8s.tusko.org ]] || { printf 'duplicate or reserved zone: %s\n' "$zone" >&2; exit 1; }
    seen_zones[$zone]=1
    envsubst "$variables" < "$root/zones/$filename" > "$output/zones/$filename"
    if [[ $role == primary ]]; then
        printf 'zone "%s" {\n    type primary;\n    file "/zones/%s";\n    allow-update { none; };\n    allow-transfer { key "zone-transfer"; };\n    notify explicit;\n    also-notify { %s port 5353 key "zone-transfer"; };\n};\n\n' "$zone" "$filename" "$DNS_SECONDARY_IPV4" >> "$output/auth/zones.conf"
    else
        printf 'zone "%s" {\n    type secondary;\n    file "/var/lib/bind/%s";\n    primaries { %s port 5353 key "zone-transfer"; };\n    allow-update-forwarding { none; };\n};\n\n' "$zone" "$filename" "$DNS_PRIMARY_IPV4" >> "$output/auth/zones.conf"
    fi
    printf 'zone "%s" {\n    type forward;\n    forward only;\n    forwarders { %s port 5353; %s port 5353; };\n};\n\n' "$zone" "$DNS_PRIMARY_IPV4" "$DNS_SECONDARY_IPV4" >> "$output/resolver/forward-zones.conf"
    printf '"%s";\n' "$zone" >> "$output/resolver/validation-exceptions.conf"
done < "$root/config/static-zones.tsv"

mkdir -p "$output/seed"
cp "$root/config/k8s.tusko.org.seed" "$output/seed/k8s.tusko.org.zone"
if [[ $role == primary ]]; then
    printf 'include "/run/secrets/externaldns.key";\nzone "k8s.tusko.org" {\n    type primary;\n    file "/var/lib/bind/k8s.tusko.org.zone";\n    update-policy { grant externaldns zonesub A AAAA CNAME TXT; };\n    allow-transfer { key "zone-transfer"; key "externaldns"; };\n    notify explicit;\n    also-notify { %s port 5353 key "zone-transfer"; };\n};\n' "$DNS_SECONDARY_IPV4" >> "$output/auth/zones.conf"
else
    printf 'zone "k8s.tusko.org" {\n    type secondary;\n    file "/var/lib/bind/k8s.tusko.org.zone";\n    primaries { %s port 5353 key "zone-transfer"; };\n    allow-update-forwarding { none; };\n};\n' "$DNS_PRIMARY_IPV4" >> "$output/auth/zones.conf"
fi
printf 'zone "k8s.tusko.org" {\n    type forward;\n    forward only;\n    forwarders { %s port 5353; %s port 5353; };\n};\n' "$DNS_PRIMARY_IPV4" "$DNS_SECONDARY_IPV4" >> "$output/resolver/forward-zones.conf"
printf '"k8s.tusko.org";\n' >> "$output/resolver/validation-exceptions.conf"

VALIDATION_EXCEPTIONS=$(< "$output/resolver/validation-exceptions.conf")
export VALIDATION_EXCEPTIONS
envsubst "$variables \${VALIDATION_EXCEPTIONS}" < "$root/config/resolver.conf.template" > "$output/resolver/named.conf"
printf 'server:\n' > "$output/pfsense-unbound.conf"
while read -r zone; do
    zone=${zone//\"/}
    zone=${zone%;}
    printf '    domain-insecure: "%s"\n    private-domain: "%s"\n    local-zone: "%s" transparent\n' "$zone" "$zone" "$zone" >> "$output/pfsense-unbound.conf"
done < "$output/resolver/validation-exceptions.conf"
while read -r zone; do
    zone=${zone//\"/}
    zone=${zone%;}
    printf 'forward-zone:\n    name: "%s"\n    forward-addr: %s\n    forward-addr: %s\n    forward-first: no\n' "$zone" "$DNS_PRIMARY_IPV4" "$DNS_SECONDARY_IPV4" >> "$output/pfsense-unbound.conf"
done < "$output/resolver/validation-exceptions.conf"
printf 'NODE_IPV4=%s\nBIND_IMAGE=%s\nBUILD_IMAGE=%s\n' "$NODE_IPV4" "$BIND_IMAGE" "${BUILD_IMAGE:-1}" > "$output/.env"
printf '%s\n' "$role" > "$output/role"
cp "$root/compose.yaml" "$output/compose.yaml"
mkdir -p "$output/scripts"
cp "$root/scripts/prepare.sh" "$root/scripts/validate.sh" "$root/scripts/probe.sh" "$root/scripts/activate.sh" "$output/scripts/"
cp "$root/Dockerfile" "$root/.dockerignore" "$output/"
printf 'rendered %s configuration in %s\n' "$role" "$output"