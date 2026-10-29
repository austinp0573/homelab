#!/bin/sh
# Create a publisher user + write ACL + access token for one topic
# usage: ./scripts/create-publisher.sh <topic>
# example: ./scripts/create-publisher.sh gatus

set -eu

TARGET_DIR=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
cd "$TARGET_DIR"

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <topic>" >&2
  exit 1
fi

topic="$1"
case "$topic" in
  *[!a-z0-9_-]* | "" | -*)
    echo "topic must use lowercase letters, numbers, hyphens, and underscores" >&2
    exit 1
    ;;
esac

user="pub-${topic}"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

# Random password for the user account (token is used for publishing)
if command -v python3 >/dev/null 2>&1; then
  pass=$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')
else
  pass=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32)
fi

echo "creating user $user for topic $topic"
if ! $COMPOSE_CMD exec -e NTFY_PASSWORD="$pass" ntfy ntfy user add "$user"; then
  echo "could not create publisher user" >&2
  echo "if the user already exists, run ./scripts/replace-publisher.sh $topic" >&2
  exit 1
fi

echo "granting write on topic $topic"
$COMPOSE_CMD exec ntfy ntfy access "$user" "$topic" write

echo "creating access token"
$COMPOSE_CMD exec ntfy ntfy token add --label="publisher-${topic}" "$user"

echo "publisher ready"
echo "copy the token above into the publisher host secret store"
echo "optional local reminder file: secrets/${topic}-token.txt (gitignored)"
echo "test:"
echo "  curl -H \"Authorization: Bearer <token>\" -d \"hi\" ${BASE_URL:-https://ntfy.example.com}/${topic}"
