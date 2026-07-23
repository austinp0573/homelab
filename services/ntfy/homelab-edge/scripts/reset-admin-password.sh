#!/usr/bin/env bash
# reset the admin password

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

user="${NTFY_ADMIN_USER:-admin}"
COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

if [ -f secrets/admin-password.txt ]; then
  pass="$(tr -d '\r\n' < secrets/admin-password.txt)"
  echo "using password from secrets/admin-password.txt"
else
  echo -n "new password for ${user}: "
  stty -echo
  read -r pass
  stty echo
  echo
fi

if [ -z "${pass}" ]; then
  echo "empty password"
  exit 1
fi
if [ "${pass}" = "change-me-now" ]; then
  echo "password cannot be change-me-now"
  exit 1
fi

echo "resetting password for ${user}"
${COMPOSE_CMD} exec -e NTFY_PASSWORD="${pass}" ntfy \
  ntfy user change-pass "${user}"
echo "admin password reset"
