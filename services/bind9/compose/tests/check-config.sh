#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
if [[ -z ${OUTPUT_ROOT:-} ]]; then
    export OUTPUT_ROOT
    OUTPUT_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/tusko-dns-config.XXXXXXXX")
fi
output=$OUTPUT_ROOT
for role in primary secondary; do
    bash "$root/scripts/render.sh" "$role" "$root/tests/local.env"
    mkdir -p "$output/$role/secrets" "$output/$role/seed"
    secret=$(openssl rand -base64 32)
    printf 'key "zone-transfer" { algorithm hmac-sha256; secret "%s"; };\n' "$secret" > "$output/$role/secrets/transfer.key"
done
cp "$output/primary/secrets/transfer.key" "$output/secondary/secrets/transfer.key"
secret=$(openssl rand -base64 32)
printf 'key "externaldns" { algorithm hmac-sha256; secret "%s"; };\n' "$secret" > "$output/primary/secrets/externaldns.key"
for role in primary secondary; do
    bash "$root/scripts/validate.sh" "$output/$role"
done
