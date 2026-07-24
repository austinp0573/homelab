#!/usr/bin/env bash
# interactive: create a username:hash line for config/users

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

image="${TINYAUTH_IMAGE:-ghcr.io/tinyauthapp/tinyauth:v5.0.7}"

mkdir -p config
touch config/users

echo "running tinyauth user create (interactive)"
echo "when it prints the user= / username:hash line, append that exact line to config/users"
echo

nerdctl run --rm -it "${image}" user create --interactive

echo
echo "append the username:hash line to config/users, then ./scripts/up.sh"
echo "optional TOTP next: ./scripts/enable-totp.sh"
