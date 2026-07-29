#!/usr/bin/env bash
# build the pi container image

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env - copy .env.example to .env and edit"
  exit 1
fi

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "building pi image"
${COMPOSE_CMD} build pi
echo "build done"
