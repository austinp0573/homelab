#!/usr/bin/env bash
# hit prometheus health and node_exporter metrics

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

bind="${HOST_BIND:-127.0.0.1}"
if [ "${bind}" = "0.0.0.0" ]; then
  bind="127.0.0.1"
fi
prom_port="${HOST_PORT:-9090}"
node_port="${NODE_EXPORTER_HOST_PORT:-9100}"

echo "GET http://${bind}:${prom_port}/-/healthy"
curl -sf "http://${bind}:${prom_port}/-/healthy" >/dev/null
echo "prometheus ok"

echo "GET http://${bind}:${node_port}/metrics"
curl -sf "http://${bind}:${node_port}/metrics" >/dev/null
echo "node_exporter ok"

echo "smoke done"
