#!/usr/bin/env bash
# stop speech stack

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "stopping speech"
${COMPOSE_CMD} down "$@"
echo "down done"
