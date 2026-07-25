#!/usr/bin/env bash
# run on the TrueNAS host (or any host with direct write access to the dataset).
# append-only rest-server clients cannot forget/prune.
#
# uses a local path repo, not the rest: url.
#
# example:
#   REPO_PATH=/mnt/coldpool/restic/admin/myhost \
#   PASSWORD_FILE=/root/restic-password.txt \
#   ./prune.sh

set -euo pipefail

REPO_PATH="${REPO_PATH:-/mnt/coldpool/restic/admin/sample-host}"
PASSWORD_FILE="${PASSWORD_FILE:-/root/restic-password.txt}"
IMAGE="${RESTIC_IMAGE:-restic/restic:0.19.1}"
RUNTIME="${CONTAINER_RUNTIME:-docker}"

KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-12}"
KEEP_YEARLY="${KEEP_YEARLY:-2}"
# default is a small weekly data check. set CHECK_ARGS= for a full check.
CHECK_ARGS="${CHECK_ARGS---read-data-subset=5%}"

if [ ! -d "${REPO_PATH}" ]; then
  echo "repo path missing: ${REPO_PATH}"
  exit 1
fi

if [ ! -f "${PASSWORD_FILE}" ]; then
  echo "password file missing: ${PASSWORD_FILE}"
  exit 1
fi

run_restic() {
  ${RUNTIME} run --rm \
    -v "${REPO_PATH}:/repo" \
    -v "${PASSWORD_FILE}:/password:ro" \
    -e RESTIC_REPOSITORY=/repo \
    -e RESTIC_PASSWORD_FILE=/password \
    "${IMAGE}" "$@"
}

echo "checking ${REPO_PATH}"
# CHECK_ARGS is an operator-controlled list of restic check arguments.
# shellcheck disable=SC2086
run_restic check ${CHECK_ARGS}

echo "pruning ${REPO_PATH}"
run_restic forget --prune \
    --keep-daily "${KEEP_DAILY}" \
    --keep-weekly "${KEEP_WEEKLY}" \
    --keep-monthly "${KEEP_MONTHLY}" \
    --keep-yearly "${KEEP_YEARLY}"

echo "prune finished"
