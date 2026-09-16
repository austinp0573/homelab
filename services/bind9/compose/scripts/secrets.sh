#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
secret_dir=${SECRETS_DIR:-$root/secrets}
action=${1:?usage: secrets.sh init AGE_RECIPIENT | decrypt}
mkdir -p "$secret_dir"
case $action in
    init)
        recipient=${2:?provide your public age recipient}
        [[ ! -e $secret_dir/keys.enc.json ]] || { printf 'encrypted keys already exist; refusing rotation\n' >&2; exit 1; }
        transfer=$(openssl rand -base64 32)
        externaldns=$(openssl rand -base64 32)
        printf '{"transfer":"%s","externaldns":"%s"}\n' "$transfer" "$externaldns" |
            sops --encrypt --age "$recipient" --input-type json --output-type json /dev/stdin > "$secret_dir/keys.enc.json.tmp"
        mv "$secret_dir/keys.enc.json.tmp" "$secret_dir/keys.enc.json"
        ;;
    decrypt)
        decrypted=$(sops --decrypt "$secret_dir/keys.enc.json")
        for key in transfer externaldns; do
            secret=$(jq -er --arg key "$key" '.[$key] | select(type == "string" and test("^[A-Za-z0-9+/]{43}=$"))' <<< "$decrypted")
            if [[ $key == transfer ]]; then name=zone-transfer; else name=externaldns; fi
            printf 'key "%s" { algorithm hmac-sha256; secret "%s"; };\n' "$name" "$secret" > "$secret_dir/$key.key.tmp"
            mv "$secret_dir/$key.key.tmp" "$secret_dir/$key.key"
        done
        ;;
    *) printf 'unknown secrets action\n' >&2; exit 1 ;;
esac
