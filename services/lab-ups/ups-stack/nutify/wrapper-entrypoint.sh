#!/bin/sh
set -eu

echo "[ups-stack] Rendering NUT configuration..."
python3 /usr/local/bin/config-init.py

echo "[ups-stack] Initializing Nutify database state..."
python3 /usr/local/bin/db-init.py

echo "[ups-stack] Starting stock Nutify entrypoint chain..."
exec "$@"
