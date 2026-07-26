#!/usr/bin/env bash
# bring the sidecar up. prefers secrets/authkey.txt over TS_AUTHKEY in .env

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env - copy .env.example to .env and edit"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

if [ -f secrets/authkey.txt ]; then
  TS_AUTHKEY="$(tr -d '\r\n' < secrets/authkey.txt)"
  export TS_AUTHKEY
  echo "using auth key from secrets/authkey.txt"
elif [ -n "${TS_AUTHKEY:-}" ]; then
  export TS_AUTHKEY
  echo "using auth key from .env"
else
  echo "no auth key set - starting anyway (needs existing state in the volume)"
fi

extra="${TS_EXTRA_ARGS:-}"

if [ -n "${HEADSCALE_URL:-}" ]; then
  extra="--login-server=${HEADSCALE_URL} ${extra}"
  echo "login-server=${HEADSCALE_URL}"
fi

if [ -n "${TS_ADVERTISE_TAGS:-}" ]; then
  extra="--advertise-tags=${TS_ADVERTISE_TAGS} ${extra}"
  echo "advertise-tags=${TS_ADVERTISE_TAGS}"
fi

case "${TS_ADVERTISE_EXIT_NODE:-false}" in
  true|TRUE|yes|y|1)
    extra="--advertise-exit-node ${extra}"
    echo "advertise-exit-node"
    ;;
esac

export TS_EXTRA_ARGS="${extra}"

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "starting compose"
${COMPOSE_CMD} up -d "$@"
echo "up done"
