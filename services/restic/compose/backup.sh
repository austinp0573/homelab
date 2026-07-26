#!/usr/bin/env bash
# one-shot backup. intended for cron.

set -Eeuo pipefail

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
  # $1 = dest var name, $2 = path var name holding the file path
  local dest="$1"
  local path_var="$2"
  local path="${!path_var:-}"
  if [ -n "${path}" ] && [ -f "${path}" ]; then
    # trim trailing newline
    export "${dest}=$(tr -d '\r\n' < "${path}")"
  fi
}

load_file RESTIC_REST_USERNAME REST_USERNAME_FILE
load_file RESTIC_REST_PASSWORD REST_PASSWORD_FILE
load_file NTFY_TOKEN NTFY_TOKEN_FILE

notify_fail() {
  if [ -n "${HC_URL}" ]; then
    curl -fsS --retry 3 "${HC_URL}/fail" >/dev/null 2>&1 || echo "healthchecks fail ping failed"
  fi

  if [ -n "${NTFY_TOPIC:-}" ]; then
    if ! command -v curl >/dev/null 2>&1; then
      echo "curl not found, ntfy notification skipped"
      return
    fi

    local -a auth=()
    if [ -n "${NTFY_TOKEN:-}" ]; then
      auth=(-H "Authorization: Bearer ${NTFY_TOKEN}")
    fi

    curl -fsS --retry 3 "${auth[@]}" \
      -d "restic backup failed on ${RESTIC_HOST:-unknown}" \
      "${NTFY_URL:-https://ntfy.sh}/${NTFY_TOPIC}" >/dev/null 2>&1 || echo "ntfy notification failed"
  fi
}

notify_ok() {
  if [ -n "${HC_URL}" ]; then
    curl -fsS --retry 3 "${HC_URL}" >/dev/null 2>&1 || echo "healthchecks success ping failed"
  fi
}

on_error() {
  local status=$?
  trap - ERR
  echo "backup failed"
  notify_fail
  exit "${status}"
}

mkdir -p /var/cache/restic/tmp

LOCK_FILE="${BACKUP_LOCK_FILE:-/var/lock/restic-backup.lock}"
mkdir -p "$(dirname "${LOCK_FILE}")"
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "backup already running"
  exit 1
fi

trap on_error ERR

case "${BACKUP_MODE:-}" in
  host)
    if [ ! -f includes.txt ]; then
      echo "missing includes.txt"
      exit 1
    fi

    echo "starting host backup"
    ${COMPOSE_CMD} run --rm restic backup \
      --insecure-tls \
      --files-from=/etc/restic/includes.txt \
      --exclude-file=/etc/restic/excludes.txt \
      --exclude-if-present CACHEDIR.TAG 
    ;;
  app)
    if [ -z "${APP_SOURCE_DIR:-}" ] || [ -z "${BACKUP_NAME:-}" ]; then
      echo "APP_SOURCE_DIR and BACKUP_NAME are required"
      exit 1
    fi

    case "${BACKUP_NAME}" in
      *[!A-Za-z0-9._-]*)
        echo "BACKUP_NAME may only contain letters, numbers, dot, dash, and underscore"
        exit 1
        ;;
    esac

    echo "staging application files"
    ./scripts/stage-files.sh

    echo "starting application backup"
    ${COMPOSE_CMD} run --rm restic backup "/app/${BACKUP_NAME}" \
      --insecure-tls \
      --exclude-if-present CACHEDIR.TAG
    ;;
  *)
    echo "BACKUP_MODE must be host or app"
    exit 1
    ;;
esac

trap - ERR
notify_ok
echo "backup finished"
