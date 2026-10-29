#!/bin/sh
# Reset the admin password

set -eu

TARGET_DIR=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
cd "$TARGET_DIR"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

user="${NTFY_ADMIN_USER:-admin}"
COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

if [ -f secrets/admin-password.txt ]; then
  pass=$(tr -d '\r\n' < secrets/admin-password.txt)
  echo "using password from secrets/admin-password.txt"
else
  printf 'new password for %s: ' "$user"
  stty -echo
  read -r pass
  stty echo
  echo
fi

if [ -z "$pass" ]; then
  echo "empty password" >&2
  exit 1
fi
if [ "$pass" = "change-me-now" ]; then
  echo "password cannot be change-me-now" >&2
  exit 1
fi

echo "resetting password for $user"
$COMPOSE_CMD exec -e NTFY_PASSWORD="$pass" ntfy ntfy user change-pass "$user"
echo "admin password reset"
