#!/bin/sh
# Create admin user for web UI / phone app
# Password from secrets/admin-password.txt or prompt

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
  printf 'password for %s: ' "$user"
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

echo "creating admin user $user"
# NTFY_PASSWORD avoids interactive prompt inside the container
if ! $COMPOSE_CMD exec -e NTFY_PASSWORD="$pass" ntfy ntfy user add --role=admin "$user"; then
  echo "could not create admin user" >&2
  echo "if the user already exists, run ./scripts/reset-admin-password.sh" >&2
  exit 1
fi

echo "admin user ready"
echo "log into ${BASE_URL:-https://ntfy.example.com} as $user"
