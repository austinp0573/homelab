#!/usr/bin/env bash
# stage vw data, backup staging to R2, copy snapshots to TrueNAS.
# healthchecks ping only if both backup and copy succeed.

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env in ${TARGET_DIR}"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"
HC_URL="${HEALTHCHECKS_URL:-}"

load_file() {
  local dest="$1"
  local path_var="$2"
  local path="${!path_var:-}"
  if [ -n "${path}" ] && [ -f "${path}" ]; then
    export "${dest}=$(tr -d '\r\n' < "${path}")"
  fi
}

notify_fail() {
  if [ -n "${HC_URL}" ]; then
    curl -fsS --retry 3 "${HC_URL}/fail" >/dev/null 2>&1 || echo "healthchecks fail ping failed"
  fi

  if [ -n "${NTFY_TOPIC:-}" ]; then
    local -a auth=()
    if [ -n "${NTFY_TOKEN:-}" ]; then
      auth=(-H "Authorization: Bearer ${NTFY_TOKEN}")
    fi
    curl -fsS --retry 3 "${auth[@]}" \
      -d "vaultwarden backup failed on ${RESTIC_HOST:-unknown}" \
      "${NTFY_URL:-https://ntfy.sh}/${NTFY_TOPIC}" >/dev/null 2>&1 || echo "ntfy notification failed"
  fi
}

notify_ok() {
  if [ -n "${HC_URL}" ]; then
    curl -fsS --retry 3 "${HC_URL}" >/dev/null 2>&1 || echo "healthchecks success ping failed"
  fi
}

on_err() {
  echo "backup-vw failed"
  notify_fail
  exit 1
}

trap on_err ERR

load_file RESTIC_REST_USERNAME REST_USERNAME_FILE
load_file RESTIC_REST_PASSWORD REST_PASSWORD_FILE
load_file NTFY_TOKEN NTFY_TOKEN_FILE

mkdir -p /var/cache/restic/tmp
mkdir -p staging

echo "staging vaultwarden data"
./stage-vw.sh

STAGE_PATH="${STAGE_DEST:-./staging/vaultwarden-data}"
# path inside the container (compose mounts ./staging -> /staging)
CONTAINER_BACKUP_PATH="/staging/vaultwarden-data"
if [ "${STAGE_PATH}" != "./staging/vaultwarden-data" ] && [ "${STAGE_PATH}" != "staging/vaultwarden-data" ]; then
  echo "STAGE_DEST should be ./staging/vaultwarden-data so it matches the compose mount"
  exit 1
fi

if [ ! -d "${STAGE_PATH}" ]; then
  echo "staging dir missing: ${STAGE_PATH}"
  exit 1
fi

echo "restic backup to R2"
# clear RESTIC_CACERT so a TrueNAS ca in the environment cannot break R2 tls
${COMPOSE_CMD} run --rm \
  -e RESTIC_CACERT= \
  restic backup "${CONTAINER_BACKUP_PATH}"

if [ ! -f secrets/truenas_repo_location.txt ]; then
  echo "missing secrets/truenas_repo_location.txt"
  exit 1
fi

echo "restic copy R2 -> TrueNAS"
${COMPOSE_CMD} run --rm \
  -e RESTIC_REPOSITORY_FILE=/run/secrets/truenas_repo_location.txt \
  -e RESTIC_FROM_REPOSITORY_FILE=/run/secrets/repo_location.txt \
  -e RESTIC_FROM_PASSWORD_FILE=/run/secrets/password.txt \
  -e RESTIC_CACERT=/certs/ca-bundle.crt \
  restic copy

trap - ERR
notify_ok
echo "backup-vw finished"
