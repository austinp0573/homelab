#!/usr/bin/env bash

set -euo pipefail

if [ ! -c /dev/kfd ]; then
  echo "missing /dev/kfd"
  exit 1
fi

if [ ! -d /dev/dri ]; then
  echo "missing /dev/dri"
  exit 1
fi

if ! command -v rocminfo >/dev/null 2>&1; then
  echo "rocminfo is not installed"
  exit 1
fi

if ! command -v amd-smi >/dev/null 2>&1; then
  echo "amd-smi is not installed"
  exit 1
fi

rocminfo | grep -E 'Name:|Marketing'
amd-smi list
