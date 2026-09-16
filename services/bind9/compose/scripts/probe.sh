#!/usr/bin/env bash
set -euo pipefail
server=${1:?usage: probe.sh DNS_NODE_IPV4 [public]}

check_record() {
    local name=$1 type=$2 expected=$3 answer
    answer=$(dig "@$server" "$name" "$type" +short +time=3 +tries=1)
    grep -Fxq "$expected" <<< "$answer" || { printf 'unexpected answer: %s %s\n%s\n' "$name" "$type" "$answer" >&2; return 1; }
}

check_record pve-01.mgmt.tusko.org A 10.0.10.21
check_record pve-02.mgmt.tusko.org A 10.0.10.22
check_record pve-03.mgmt.tusko.org A 10.0.10.23
check_record mtl-01.dmz.tusko.org A 10.0.90.15
check_record vm-05.dmz.tusko.org A 10.0.90.11
check_record vm-06.dmz.tusko.org A 10.0.90.12
check_record homelable.dmz.tusko.org A 10.0.90.12
check_record 12.90.0.10.in-addr.arpa PTR vm-06.dmz.tusko.org.
for zone in mgmt.tusko.org dmz.tusko.org k8s.tusko.org 10.0.10.in-addr.arpa 20.0.10.in-addr.arpa 30.0.10.in-addr.arpa 40.0.10.in-addr.arpa 90.0.10.in-addr.arpa; do
    answer=$(dig "@$server" "$zone" SOA +tcp +short +time=3 +tries=1)
    [[ $answer == dns-primary.mgmt.tusko.org.* ]] || { printf 'missing SOA over TCP: %s\n' "$zone" >&2; exit 1; }
done
if [[ ${2:-} == public ]]; then
    answer=$(dig "@$server" cloudflare.com A +dnssec +time=5 +tries=1)
    [[ $answer == *'status: NOERROR'* ]] && grep -Eq 'flags:.* ad[ ;]' <<< "$answer" || { printf 'public DNSSEC validation failed\n%s\n' "$answer" >&2; exit 1; }
    answer=$(dig "@$server" dnssec-failed.org A +dnssec +time=5 +tries=1)
    [[ $answer == *'status: SERVFAIL'* ]] || { printf 'bogus DNSSEC response was accepted\n' >&2; exit 1; }
fi
printf 'DNS probes passed for %s\n' "$server"
