#!/usr/bin/env bash
# create a publisher user + write ACL + access token for one topic
# usage: ./scripts/create-publisher.sh <topic>
# example: ./scripts/create-publisher.sh gatus

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

# random password for the user account (we use a token for publishing)
pass="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(24))
PY
)"

echo "creating user ${user} for topic ${topic}"
if ! ${COMPOSE_CMD} exec -e NTFY_PASSWORD="${pass}" ntfy \
  ntfy user add "${user}"; then
  echo "could not create publisher user"
  echo "if the user already exists, run ./scripts/replace-publisher.sh ${topic}"
  exit 1
fi

echo "granting write on topic ${topic}"
${COMPOSE_CMD} exec ntfy ntfy access "${user}" "${topic}" write

echo "creating access token"
${COMPOSE_CMD} exec ntfy ntfy token add --label="publisher-${topic}" "${user}"

echo "publisher ready"
echo "copy the token above into the publisher host secret store"
echo "optional local reminder file: secrets/${topic}-token.txt (gitignored)"
echo "test:"
echo "  curl -H \"Authorization: Bearer <token>\" -d \"hi\" ${BASE_URL:-https://ntfy.example.com}/${topic}"
