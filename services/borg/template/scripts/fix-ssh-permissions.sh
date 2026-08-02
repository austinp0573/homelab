#!/bin/sh

# run from anywhere

set -eu

unset CDPATH

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
sample_dir=$(cd -- "$script_dir/.." && pwd)

ssh_dir="$sample_dir/secrets/ssh"
passphrase_file="$sample_dir/secrets/passphrase.txt"

echo setting permissions

mkdir -p "$ssh_dir"

chmod 755 "$sample_dir/secrets"
chmod 755 "$ssh_dir"

if [ "$(id -u)" -eq 0 ]; then
    chown root:root "$sample_dir/secrets" "$ssh_dir"
else
    echo run with sudo to set root ownership
fi

if [ -f "$ssh_dir/id_ed25519" ]; then
    if [ "$(id -u)" -eq 0 ]; then
        chown root:root "$ssh_dir/id_ed25519"
    fi
    chmod 600 "$ssh_dir/id_ed25519"
fi

if [ -f "$ssh_dir/known_hosts" ]; then
    if [ "$(id -u)" -eq 0 ]; then
        chown root:root "$ssh_dir/known_hosts"
    fi
    chmod 644 "$ssh_dir/known_hosts"
fi

if [ -f "$passphrase_file" ]; then
    if [ "$(id -u)" -eq 0 ]; then
        chown root:root "$passphrase_file"
    fi
    chmod 644 "$passphrase_file"
fi

echo "done"
