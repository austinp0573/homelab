#!/usr/bin/env bash
set -euo pipefail
umask 077
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
role=${1:?usage: deploy.sh primary|secondary SSH_TARGET [env-file]}
target=${2:?provide an SSH target with root access}
[[ $target =~ ^[a-zA-Z0-9][a-zA-Z0-9_.@:-]+$ ]] || { printf 'invalid SSH target\n' >&2; exit 1; }
bash "$root/scripts/render.sh" "$role" "${3:-$root/.env}"
bash "$root/scripts/secrets.sh" decrypt
bundle=${OUTPUT_ROOT:-$root/build}/$role
install -d -m 0700 "$bundle/secrets"
install -m 0600 "$root/secrets/transfer.key" "$bundle/secrets/transfer.key"
if [[ $role == primary ]]; then
    install -m 0600 "$root/secrets/externaldns.key" "$bundle/secrets/externaldns.key"
else
    rm -f "$bundle/secrets/externaldns.key"
fi
ssh -o BatchMode=yes "$target" 'test "$(id -u)" = 0 && command -v bash && command -v nerdctl' >/dev/null
release=$(ssh -o BatchMode=yes "$target" 'umask 077; mkdir -p /opt/dns/releases; mktemp -d /opt/dns/releases/release.XXXXXXXX')
[[ $release =~ ^/opt/dns/releases/release\.[a-zA-Z0-9]+$ ]] || { printf 'invalid remote release path\n' >&2; exit 1; }
tar -C "$bundle" -cf - . | ssh -o BatchMode=yes "$target" "tar -C '$release' -xf -"
ssh -o BatchMode=yes "$target" "bash '$release/scripts/activate.sh' '$release'"
