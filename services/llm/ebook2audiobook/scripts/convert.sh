#!/usr/bin/env bash

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env - copy .env.example to .env and edit"
  exit 1
fi

if [ "$#" -lt 1 ]; then
  echo "usage: $0 file.epub [ebook2audiobook options]"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

book="$1"
shift

case "${book}" in
  /*|*..*)
    echo "ebook must be a relative path under EBOOKS_DIR"
    exit 1
    ;;
esac

if [ ! -f "${EBOOKS_DIR:-/opt/llm/ebooks}/${book}" ]; then
  echo "ebook not found: ${EBOOKS_DIR:-/opt/llm/ebooks}/${book}"
  exit 1
fi

COMPOSE_CMD="${COMPOSE_CMD:-nerdctl compose}"

echo "converting ${book}"
${COMPOSE_CMD} run --rm ebook2audiobook \
  --headless \
  --ebook "/app/ebooks/${book}" \
  --language "${EBOOK_LANGUAGE:-eng}" \
  "$@"
