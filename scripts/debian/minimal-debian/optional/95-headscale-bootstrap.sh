#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

# creates a headscale user + reusable preauth key. run after optional/93-headscale.sh.
# defaults (override in .env)
HEADSCALE_BOOTSTRAP_USER="${HEADSCALE_BOOTSTRAP_USER:-edge}"
HEADSCALE_BOOTSTRAP_KEY_OUT="${HEADSCALE_BOOTSTRAP_KEY_OUT:-/root/headscale-preauth.key}"
HEADSCALE_BOOTSTRAP_EXPIRATION="${HEADSCALE_BOOTSTRAP_EXPIRATION:-90d}"
HEADSCALE_BOOTSTRAP_REUSABLE="${HEADSCALE_BOOTSTRAP_REUSABLE:-y}"

echo "headscale bootstrap"

if ! command -v headscale >/dev/null 2>&1; then
    echo "headscale not installed - run optional/93-headscale.sh first"
    exit 1
fi

if ! systemctl is-active --quiet headscale; then
    echo "headscale service not active"
    exit 1
fi

if headscale users list 2>/dev/null | grep -qw "$HEADSCALE_BOOTSTRAP_USER"; then
    echo "user ${HEADSCALE_BOOTSTRAP_USER} already exists"
else
    echo "creating user ${HEADSCALE_BOOTSTRAP_USER}"
    headscale users create "$HEADSCALE_BOOTSTRAP_USER"
fi

reuse_args=()
if is_yes "$HEADSCALE_BOOTSTRAP_REUSABLE"; then
    reuse_args+=(--reusable)
fi

echo "creating preauth key (expiration ${HEADSCALE_BOOTSTRAP_EXPIRATION})"
# headscale output formats vary by version - capture full output
key_out=$(headscale preauthkeys create \
    --user "$HEADSCALE_BOOTSTRAP_USER" \
    --expiration "$HEADSCALE_BOOTSTRAP_EXPIRATION" \
    "${reuse_args[@]}" 2>&1) || {
    echo "$key_out"
    exit 1
}

echo "$key_out"
key="$(printf '%s\n' "$key_out" | grep -Eo 'tskey-[[:alnum:]_-]+' | tail -n 1 || true)"
if [ -z "$key" ]; then
    echo "could not read preauth key from headscale output"
    exit 1
fi

umask 077
printf '%s\n' "$key" > "$HEADSCALE_BOOTSTRAP_KEY_OUT"
chmod 600 "$HEADSCALE_BOOTSTRAP_KEY_OUT"
echo "wrote ${HEADSCALE_BOOTSTRAP_KEY_OUT}"

echo "join a node with:"
echo "  tailscale up --login-server=${HEADSCALE_URL:-https://headscale.example.com} --authkey=\$(cat ${HEADSCALE_BOOTSTRAP_KEY_OUT}) --hostname=<name>"
echo "headscale bootstrap done"
