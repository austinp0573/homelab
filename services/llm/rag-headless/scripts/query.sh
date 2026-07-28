#!/usr/bin/env bash
# embed a query and print top chunks from qdrant

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TARGET_DIR}"

if [ ! -f .env ]; then
  echo "missing .env"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

if [ "$#" -lt 1 ]; then
  echo "usage: $0 \"your question\""
  exit 1
fi

query="$1"
collection="${QDRANT_COLLECTION:-lab}"
qdrant="http://127.0.0.1:${QDRANT_HOST_PORT:-6333}"
embed="http://127.0.0.1:${EMBED_HOST_PORT:-8081}/v1/embeddings"
limit="${QUERY_LIMIT:-5}"

python3 - "${query}" "${embed}" "${qdrant}" "${collection}" "${limit}" <<'PY'
import json, sys, urllib.request

query, embed_url, qdrant, collection, limit = sys.argv[1:6]
limit = int(limit)

body = json.dumps({"input": query, "model": "embed"}).encode()
req = urllib.request.Request(embed_url, data=body, headers={"Content-Type": "application/json"})
with urllib.request.urlopen(req) as resp:
    vec = json.load(resp)["data"][0]["embedding"]

search = json.dumps({"vector": vec, "limit": limit, "with_payload": True}).encode()
req = urllib.request.Request(
    f"{qdrant}/collections/{collection}/points/search",
    data=search,
    headers={"Content-Type": "application/json"},
)
with urllib.request.urlopen(req) as resp:
    hits = json.load(resp).get("result", [])

for i, hit in enumerate(hits, 1):
    payload = hit.get("payload") or {}
    score = hit.get("score")
    path = payload.get("path", "?")
    text = payload.get("text", "")
    print(f"--- {i} score={score:.4f} path={path}")
    print(text)
    print()
PY
