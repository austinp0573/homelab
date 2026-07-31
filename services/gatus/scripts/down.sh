#!/usr/bin/env bash
# stop gatus

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "stopping gatus"
${COMPOSE_CMD} down "$@"
echo "down done"
