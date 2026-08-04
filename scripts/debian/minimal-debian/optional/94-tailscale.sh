#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

# defaults (override in .env) — blank means unused
HEADSCALE_URL="${HEADSCALE_URL:-}"
TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-}"
TAILSCALE_ADVERTISE_ROUTES="${TAILSCALE_ADVERTISE_ROUTES:-}"
TAILSCALE_ADVERTISE_EXIT_NODE="${TAILSCALE_ADVERTISE_EXIT_NODE:-n}"

echo "tailscale"

apt_install curl ca-certificates

if ! command -v tailscale >/dev/null 2>&1; then
    . /etc/os-release
    codename="${VERSION_CODENAME:-trixie}"
    install -d -m 0755 /usr/share/keyrings
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/${codename}.noarmor.gpg" \
        -o /usr/share/keyrings/tailscale-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian ${codename} main" \
        > /etc/apt/sources.list.d/tailscale.list
    apt_update_once
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tailscale
else
    echo "tailscale already installed"
fi

systemctl enable --now tailscaled

# build up args only when something is set
up_args=()

if [ -n "$HEADSCALE_URL" ]; then
    up_args+=(--login-server="$HEADSCALE_URL")
    echo "login-server=$HEADSCALE_URL"
else
    echo "HEADSCALE_URL empty — using Tailscale SaaS"
fi

if [ -n "$TAILSCALE_HOSTNAME" ]; then
    up_args+=(--hostname="$TAILSCALE_HOSTNAME")
fi

if [ -n "$TAILSCALE_ADVERTISE_ROUTES" ]; then
    up_args+=(--advertise-routes="$TAILSCALE_ADVERTISE_ROUTES")
fi

if is_yes "$TAILSCALE_ADVERTISE_EXIT_NODE"; then
    up_args+=(--advertise-exit-node)
fi

if [ -n "$TAILSCALE_AUTH_KEY" ]; then
    up_args+=(--authkey="$TAILSCALE_AUTH_KEY")
    echo "running: tailscale up ..."
    tailscale up "${up_args[@]}"
    echo "tailscale up done"
else
    echo "TAILSCALE_AUTH_KEY empty — tailscaled running; join later with:"
    if [ ${#up_args[@]} -gt 0 ]; then
        echo "  tailscale up ${up_args[*]} --authkey=<key>"
    else
        echo "  tailscale up --authkey=<key>"
    fi
fi

echo "tailscale done"
