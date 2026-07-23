#!/usr/bin/env bash
# print web push VAPID keys to paste into config/server.yml

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "generating web push keys"
${COMPOSE_CMD} exec ntfy ntfy webpush keys
echo
echo "paste public/private into config/server.yml under web-push-*"
echo "uncomment web-push-file and web-push-email-address"
echo "then: nerdctl compose up -d --force-recreate"
