#!/bin/sh

# run this from the copied sample directory

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sample_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

if [ -f "$sample_dir/.env" ]; then
    set -a
    . "$sample_dir/.env"
    set +a
fi

host=${TRUENAS_HOST:-10.0.0.1}
port=${BORG_REMOTE_PORT:-22}
out="$sample_dir/secrets/ssh/known_hosts"

mkdir -p "$sample_dir/secrets/ssh"

echo scanning host
ssh-keyscan -p "$port" "$host" > "$out"
chmod 644 "$out"
echo wrote known_hosts
