#!/bin/sh
# Replace a publisher user and revoke its old tokens

set -eu

SCRIPT_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd)
TARGET_DIR=$(cd -P -- "$SCRIPT_DIR/.." && pwd)
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

echo "removing $user and revoking its tokens"
if ! $COMPOSE_CMD exec ntfy ntfy user del "$user"; then
  echo "could not remove publisher user" >&2
  echo "if the user does not exist, run ./scripts/create-publisher.sh $topic" >&2
  exit 1
fi

exec "$SCRIPT_DIR/create-publisher.sh" "$topic"
