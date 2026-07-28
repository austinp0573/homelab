#!/usr/bin/env bash
# POST a wav/mp3 to whisper and print the text

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if [ "$#" -lt 1 ]; then
  echo "usage: $0 /path/to/audio.wav"
  exit 1
fi

audio="$1"
port="${WHISPER_HOST_PORT:-9000}"

echo "transcribing ${audio}"
curl -sf "http://127.0.0.1:${port}/v1/audio/transcriptions" \
  -F "file=@${audio}" \
  -F "model=whisper-1"
echo
