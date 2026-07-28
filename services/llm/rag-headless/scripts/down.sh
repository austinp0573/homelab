#!/usr/bin/env bash
# stop rag-headless

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "stopping rag-headless"
${COMPOSE_CMD} down "$@"
echo "down done"
