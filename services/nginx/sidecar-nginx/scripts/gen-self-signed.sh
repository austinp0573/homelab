#!/usr/bin/env bash
# self-signed cert for config/tls demo

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

OUT_DIR="${TARGET_DIR}/secrets/certs"
mkdir -p "${OUT_DIR}"

if [ -f "${OUT_DIR}/privkey.pem" ] || [ -f "${OUT_DIR}/fullchain.pem" ]; then
  echo "secrets/certs already has certs - remove them first if you want to recreate"
  exit 1
fi

CN="${TLS_CN:-localhost}"

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "${OUT_DIR}/privkey.pem" \
  -out "${OUT_DIR}/fullchain.pem" \
  -days 825 \
  -subj "/CN=${CN}"

chmod 644 "${OUT_DIR}/fullchain.pem"
chmod 600 "${OUT_DIR}/privkey.pem"
echo "wrote ${OUT_DIR}/fullchain.pem and privkey.pem (CN=${CN})"
