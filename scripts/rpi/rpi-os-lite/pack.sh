#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

tar -cf send.tar \
    --exclude='.git' \
    --exclude='.env' \
    --exclude='send.tar' \
    --exclude='pack.sh' \
    --exclude='README.md' \
    .

echo "created send.tar"
