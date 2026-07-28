#!/usr/bin/env bash

set -euo pipefail

network="${1:-llm-backend}"

if nerdctl network inspect "${network}" >/dev/null 2>&1; then
  exit 0
fi

echo "creating network ${network}"
nerdctl network create "${network}" >/dev/null
