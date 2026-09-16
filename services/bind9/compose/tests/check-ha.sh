#!/usr/bin/env bash
set -euo pipefail
umask 077

[[ $EUID == 0 ]] || { printf 'run this isolated container test as root\n' >&2; exit 1; }
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
export CONTAINERD_NAMESPACE=${CONTAINERD_NAMESPACE:-tusko-dns-validation}
nerdctl_bin=${NERDCTL:-nerdctl}
export OUTPUT_ROOT
OUTPUT_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/tusko-dns-test.XXXXXXXX")
added_addresses=()

compose() {
    local role=$1
    shift
    DATA_DIR="$OUTPUT_ROOT/state/$role" "$nerdctl_bin" --namespace "$CONTAINERD_NAMESPACE" compose \
        -p "tusko-dns-test-$role" --env-file "$OUTPUT_ROOT/$role/.env" \
        -f "$OUTPUT_ROOT/$role/compose.yaml" "$@"
}

cleanup() {
    local status=$?
    trap - EXIT
    for role in primary secondary; do
        if [[ -f $OUTPUT_ROOT/$role/compose.yaml ]]; then
            if [[ $status != 0 ]]; then compose "$role" logs --tail 50 || true; fi
            compose "$role" down >/dev/null 2>&1 || true
        fi
    done
    for address in "${added_addresses[@]}"; do
        ip address del "$address/32" dev lo || true
    done
    printf 'test artifacts retained in %s\n' "$OUTPUT_ROOT"
    exit "$status"
}
trap cleanup EXIT

wait_record() {
    local server=$1 port=$2 name=$3 type=$4 expected=$5 response deadline
    deadline=$((SECONDS + 40))
    while (( SECONDS < deadline )); do
        response=$(dig "@$server" -p "$port" "$name" "$type" +short +time=1 +tries=1) || continue
        if grep -Fxq "$expected" <<< "$response"; then return 0; fi
    done
    printf 'record check failed: %s:%s %s %s expected %s\n' "$server" "$port" "$name" "$type" "$expected" >&2
    return 1
}

for address in 127.0.0.2 127.0.0.3; do
    if ! ip -j -4 address show dev lo | jq -e --arg address "$address" 'any(.[].addr_info[]; .local == $address)' >/dev/null; then
        ip address add "$address/32" dev lo
        added_addresses+=("$address")
    fi
    for port in 53 5353; do
        if dig "@$address" -p "$port" mgmt.tusko.org SOA +time=1 +tries=1 >/dev/null 2>&1; then
            printf 'a DNS server already responds on %s:%s; refusing to interfere\n' "$address" "$port" >&2
            exit 1
        fi
    done
done

bash "$root/tests/check-config.sh"
for role in primary secondary; do
    bash "$root/scripts/prepare.sh" "$OUTPUT_ROOT/$role" "$OUTPUT_ROOT/state/$role"
    compose "$role" config --quiet
    compose "$role" up -d --pull never
done

for address in 127.0.0.2 127.0.0.3; do
    wait_record "$address" 5353 pve-01.mgmt.tusko.org A 10.0.10.21
    wait_record "$address" 53 homelable.dmz.tusko.org A 10.0.90.12
    wait_record "$address" 53 12.90.0.10.in-addr.arpa PTR vm-06.dmz.tusko.org.
    response=$(dig -b 127.0.0.4 "@$address" pve-01.mgmt.tusko.org A +time=2 +tries=1)
    [[ $response == *'status: REFUSED'* ]] || { printf 'unlisted client was not refused\n' >&2; exit 1; }
    response=$(dig "@$address" -p 5353 mgmt.tusko.org AXFR +time=2 +tries=1)
    [[ $response == *'Transfer failed.'* ]] || { printf 'unsigned AXFR was not rejected\n' >&2; exit 1; }
    response=$(dig "@$address" -p 5353 cloudflare.com A +time=2 +tries=1)
    [[ $response != *' ra;'* && $response != *' ra '* ]] || { printf 'authority offers recursion\n' >&2; exit 1; }
done

if [[ ${RUN_PUBLIC_TESTS:-1} == 1 ]]; then
    bash "$root/scripts/probe.sh" 127.0.0.2 public
    bash "$root/scripts/probe.sh" 127.0.0.3 public
fi

response=$(dig @127.0.0.2 -p 5353 -k "$OUTPUT_ROOT/primary/secrets/transfer.key" mgmt.tusko.org AXFR +time=2 +tries=1)
grep -q 'pve-01.mgmt.tusko.org.' <<< "$response"
printf 'PASS: initial records and transfer access controls\n'
nsupdate -v -k "$OUTPUT_ROOT/primary/secrets/externaldns.key" <<'UPDATE'
server 127.0.0.2 5353
zone k8s.tusko.org.
update add probe.k8s.tusko.org. 60 A 10.0.90.99
send
UPDATE
wait_record 127.0.0.3 5353 probe.k8s.tusko.org A 10.0.90.99
if nsupdate -v -k "$OUTPUT_ROOT/primary/secrets/externaldns.key" <<'UPDATE'
server 127.0.0.2 5353
zone mgmt.tusko.org.
update add forbidden.mgmt.tusko.org. 60 A 10.0.90.99
send
UPDATE
then printf 'ExternalDNS key changed a static zone\n' >&2; exit 1; fi

compose primary stop
compose secondary restart authoritative
compose secondary restart recursive
wait_record 127.0.0.3 53 pve-02.mgmt.tusko.org A 10.0.10.22
wait_record 127.0.0.3 53 probe.k8s.tusko.org A 10.0.90.99
compose primary start
wait_record 127.0.0.2 5353 pve-03.mgmt.tusko.org A 10.0.10.23
compose secondary stop
compose primary restart recursive
wait_record 127.0.0.2 53 pve-03.mgmt.tusko.org A 10.0.10.23
compose secondary start
printf 'PASS: records, authenticated transfers, update isolation, and either-node failure\n'
