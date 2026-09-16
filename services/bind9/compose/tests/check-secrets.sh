#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
export SECRETS_DIR SOPS_AGE_KEY_FILE
SECRETS_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tusko-dns-secrets.XXXXXXXX")
SOPS_AGE_KEY_FILE=$SECRETS_DIR/identity.key
trap 'rm -rf -- "$SECRETS_DIR"' EXIT
age-keygen -o "$SOPS_AGE_KEY_FILE" 2>/dev/null
recipient=$(age-keygen -y "$SOPS_AGE_KEY_FILE")
bash "$root/scripts/secrets.sh" init "$recipient"
jq -e '.transfer | startswith("ENC[")' "$SECRETS_DIR/keys.enc.json" >/dev/null
before=$(sha256sum "$SECRETS_DIR/keys.enc.json")
if bash "$root/scripts/secrets.sh" init "$recipient"; then
    printf 'existing encrypted keys were overwritten\n' >&2; exit 1
fi
[[ $before == "$(sha256sum "$SECRETS_DIR/keys.enc.json")" ]]
bash "$root/scripts/secrets.sh" decrypt
grep -q 'key "zone-transfer"' "$SECRETS_DIR/transfer.key"
grep -q 'key "externaldns"' "$SECRETS_DIR/externaldns.key"
[[ $(stat -c %a "$SECRETS_DIR/transfer.key") == 600 ]]
[[ $(stat -c %a "$SECRETS_DIR/externaldns.key") == 600 ]]
printf 'PASS: SOPS/age round trip, overwrite refusal, and private key permissions\n'
