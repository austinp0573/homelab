#!/usr/bin/env bash
# replace a publisher user and revoke its old tokens

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <topic>"
  exit 1
fi

topic="$1"
if ! [[ "${topic}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "topic must use lowercase letters, numbers, hyphens, and underscores"
  exit 1
fi
user="pub-${topic}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "removing ${user} and revoking its tokens"
if ! ${COMPOSE_CMD} exec ntfy ntfy user del "${user}"; then
  echo "could not remove publisher user"
  echo "if the user does not exist, run ./scripts/create-publisher.sh ${topic}"
  exit 1
fi

exec ./scripts/create-publisher.sh "${topic}"
