#!/usr/bin/env bash
# interactive: add TOTP to an existing username:hash line

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f config/users ]; then
  echo "missing config/users"
  exit 1
fi

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

image="${TINYAUTH_IMAGE:-ghcr.io/tinyauthapp/tinyauth:v5.0.7}"

echo "running tinyauth totp generate (interactive)"
echo "it asks for the current username:hash, shows a QR, then prints username:hash:totp"
echo "replace the old line in config/users with the new one"
echo

nerdctl run --rm -it "${image}" totp generate --interactive

echo
echo "edit config/users: replace the user line with the new username:hash:totp line"
echo "then: ./scripts/up.sh"
echo
echo "optional verify:"
echo "  nerdctl run --rm -it ${image} user verify --interactive"
