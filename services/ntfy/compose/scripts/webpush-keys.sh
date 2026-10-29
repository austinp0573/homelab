#!/bin/sh
# Print web push VAPID keys to paste into config/server.yml

set -eu

TARGET_DIR=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
cd "$TARGET_DIR"

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "generating web push keys"
$COMPOSE_CMD exec ntfy ntfy raw web-push keys
echo
echo "paste public/private into server.yml under web-push-*"
echo "uncomment web-push-file and web-push-email-address"
echo "then: nerdctl compose up -d --force-recreate"
