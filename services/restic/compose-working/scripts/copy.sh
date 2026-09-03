#!/bin/sh
# copy snapshots from the primary repository to secondary backends

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="${COMPOSE_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
cd "${COMPOSE_DIR}" || exit 1

if [ ! -f .env ]; then
  echo "missing .env in ${COMPOSE_DIR}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. .env
set +a

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

if [ -n "${REST_USERNAME_FILE:-}" ] && [ -f "${REST_USERNAME_FILE}" ]; then
  export RESTIC_REST_USERNAME="$(tr -d '\r\n' < "${REST_USERNAME_FILE}")"
fi
if [ -n "${REST_PASSWORD_FILE:-}" ] && [ -f "${REST_PASSWORD_FILE}" ]; then
  export RESTIC_REST_PASSWORD="$(tr -d '\r\n' < "${REST_PASSWORD_FILE}")"
fi

# Define secondary target backends to copy snapshots to.
# You can uncomment & configure targets here, or pass them as CLI arguments.
TARGET_REPOS=""

# Example 1: Cloudflare R2 / S3
# TARGET_REPOS="${TARGET_REPOS} s3:https://<ACCOUNT_ID>.r2.cloudflarestorage.com/<BUCKET_NAME>"

# Example 2: SFTP
# TARGET_REPOS="${TARGET_REPOS} sftp:user@host:/path/to/backup/repo"

# Example 3: Secondary REST Server
# TARGET_REPOS="${TARGET_REPOS} rest:https://secondary-server:8000/repo"

# If CLI arguments were passed, use them as target repos
if [ "$#" -gt 0 ]; then
  TARGET_REPOS="$*"
fi

if [ -z "${TARGET_REPOS}" ]; then
  echo "Usage: $0 <target_repo_url...>" >&2
  echo "Or configure TARGET_REPOS inside scripts/copy.sh" >&2
  exit 1
fi

for TARGET in ${TARGET_REPOS}; do
  echo "===> Copying snapshots to ${TARGET}"
  # shellcheck disable=SC2086
  ${COMPOSE_CMD} run --rm \
    -e RESTIC_FROM_REPOSITORY_FILE=/run/secrets/repo_location.txt \
    -e RESTIC_FROM_PASSWORD_FILE=/run/secrets/password.txt \
    restic --insecure-tls copy \
      --repo "${TARGET}" \
      --password-file /run/secrets/password.txt
done

echo "copy finished"
