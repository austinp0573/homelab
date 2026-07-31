#!/usr/bin/env bash
# write secrets/htpasswd for the optional auth sidecar

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

mkdir -p secrets
OUT="${TARGET_DIR}/secrets/htpasswd"

if [ -f "${OUT}" ]; then
  echo "secrets/htpasswd already exists - remove it first if you want to recreate"
  exit 1
fi

USER_NAME="${AUTH_USER:-}"
PASS="${AUTH_PASS:-}"

if [ -z "${USER_NAME}" ]; then
  printf "username: "
  read -r USER_NAME
fi
if [ -z "${PASS}" ]; then
  printf "password: "
  stty -echo
  read -r PASS
  stty echo
  echo
fi

if [ -z "${USER_NAME}" ] || [ -z "${PASS}" ]; then
  echo "need username and password"
  exit 1
fi

# apr1 is the boring option nginx always accepts
if command -v openssl >/dev/null 2>&1; then
  HASH="$(openssl passwd -apr1 "${PASS}")"
  echo "${USER_NAME}:${HASH}" > "${OUT}"
elif command -v htpasswd >/dev/null 2>&1; then
  htpasswd -nb "${USER_NAME}" "${PASS}" > "${OUT}"
else
  echo "need openssl or htpasswd"
  exit 1
fi

# readable inside the nginx container (file stays gitignored)
chmod 644 "${OUT}"
echo "wrote ${OUT}"
