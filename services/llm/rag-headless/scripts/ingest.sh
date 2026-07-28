#!/usr/bin/env bash
# chunk files from DOCS_DIR, embed, upsert into qdrant

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

docs_dir="${DOCS_DIR:-/opt/llm/rag/docs}"
collection="${QDRANT_COLLECTION:-lab}"
qdrant="http://127.0.0.1:${QDRANT_HOST_PORT:-6333}"
embed="http://127.0.0.1:${EMBED_HOST_PORT:-8081}/v1/embeddings"
vector_size="${EMBED_VECTOR_SIZE:-768}"
chunk_size="${CHUNK_SIZE:-800}"
overlap="${CHUNK_OVERLAP:-100}"

if [ ! -d "${docs_dir}" ]; then
  echo "docs dir missing: ${docs_dir}"
  exit 1
fi

collection_file="$(mktemp)"
trap 'rm -f "${collection_file}"' EXIT

echo "ensuring collection ${collection}"
code="$(curl -s -o "${collection_file}" -w '%{http_code}' "${qdrant}/collections/${collection}" || true)"
if [ "${code}" != "200" ]; then
  curl -sf -X PUT "${qdrant}/collections/${collection}" \
    -H 'Content-Type: application/json' \
    -d "{\"vectors\":{\"size\":${vector_size},\"distance\":\"Cosine\"}}" >/dev/null
  echo "created collection"
else
  echo "collection exists"
fi

python3 - "${docs_dir}" "${chunk_size}" "${overlap}" "${embed}" "${qdrant}" "${collection}" <<'PY'
import json, os, sys, urllib.request, hashlib

docs_dir, chunk_size, overlap, embed_url, qdrant, collection = sys.argv[1:7]
chunk_size = int(chunk_size)
overlap = int(overlap)

def chunk_text(text, size, ov):
    text = text.replace("\r\n", "\n")
    out = []
    i = 0
    n = len(text)
    while i < n:
        piece = text[i:i+size].strip()
        if piece:
            out.append(piece)
        if i + size >= n:
            break
        i += max(size - ov, 1)
    return out

def embed(text):
    body = json.dumps({"input": text, "model": "embed"}).encode()
    req = urllib.request.Request(embed_url, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        data = json.load(resp)
    return data["data"][0]["embedding"]

def upsert(points):
    body = json.dumps({"points": points}).encode()
    req = urllib.request.Request(
        f"{qdrant}/collections/{collection}/points?wait=true",
        data=body,
        headers={"Content-Type": "application/json"},
        method="PUT",
    )
    with urllib.request.urlopen(req) as resp:
        resp.read()

exts = {".md", ".txt", ".markdown"}
batch = []
count = 0

for root, _dirs, files in os.walk(docs_dir):
    for name in files:
        path = os.path.join(root, name)
        if os.path.splitext(name)[1].lower() not in exts:
            continue
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            text = f.read()
        rel = os.path.relpath(path, docs_dir)
        for idx, piece in enumerate(chunk_text(text, chunk_size, overlap)):
            pid = int(hashlib.sha1(f"{rel}:{idx}".encode()).hexdigest()[:15], 16)
            vec = embed(piece)
            batch.append({
                "id": pid,
                "vector": vec,
                "payload": {"path": rel, "chunk": idx, "text": piece},
            })
            count += 1
            if len(batch) >= 8:
                upsert(batch)
                print(f"upserted {count}")
                batch = []

if batch:
    upsert(batch)
print(f"done, chunks={count}")
PY
