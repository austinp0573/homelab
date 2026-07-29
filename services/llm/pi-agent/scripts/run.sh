#!/usr/bin/env bash
# run pi against a host project directory

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env - copy .env.example to .env and edit"
  exit 1
fi

if [ "$#" -lt 1 ]; then
  echo "usage: $0 /path/to/project [extra pi args...]"
  exit 1
fi

project="$1"
shift

if [ ! -d "${project}" ]; then
  echo "not a directory: ${project}"
  exit 1
fi

# resolve to absolute path for the bind mount
project="$(cd "${project}" && pwd)"
export PROJECT_DIR="${project}"

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "project=${PROJECT_DIR}"
echo "starting pi (make sure llama-cpp is up)"
# shellcheck disable=SC2086
${COMPOSE_CMD} run --rm pi "$@"
