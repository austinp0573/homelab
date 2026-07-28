# rag-headless

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### qdrant

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-3% | ~100-200 MB empty/small | storage grows with vectors | idle |
| expected | 5-20% | ~300 MB-1 GB for modest collections | vector DB can be hundreds of MB to many GB | upsert/search from open-webui |
| high | 1+ core | ~2-4 GB+ for large collections | disk scales with embeddings stored | bulk reindex / big semantic search |

### embed

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-5% idle | ~300-800 MB with a small embedding model resident | model weights hundreds of MB to a few GB | idle |
| expected | 1-2 CPU cores while embedding | ~1-2 GB | model files on disk | doc ingest batches |
| high | all CPU cores you give it | ~2-4 GB for larger embedding models | same | re-embedding a large library |

This stack is meant to stay on CPU so llama.cpp can own the GPU.

deploy path: `/opt/llm-rag-headless`

This stack runs Qdrant and the embedding API used by Open WebUI. The embedding model stays on CPU so document QA can run while llama.cpp owns the GPU.

## first run

1. Create `/opt/llm/models`, `/opt/llm/rag/docs`, and `/opt/llm/rag/qdrant`.
2. Put `nomic-embed-text-v1.5.Q8_0.gguf` in `/opt/llm/models`.
3. Copy this directory to `/opt/llm-rag-headless`.
4. Copy `.env.example` to `.env`.
5. Run `./scripts/up.sh`.
6. Start Open WebUI and upload documents there.

Qdrant and the embedding API bind to loopback on the host. Open WebUI reaches them over `llm-backend`.

## document QA

Open WebUI owns the normal document flow:

- upload Markdown, text, PDF, or EPUB files in Workspace
- add files to a knowledge base
- attach that knowledge base to a chat
- use `#https://example.com/page` in a chat to fetch one web page

Open WebUI writes its vectors to Qdrant. Do not run `ingest.sh` against an Open WebUI collection.

## plain text scripts

`ingest.sh` and `query.sh` are for a separate simple collection named by `QDRANT_COLLECTION`. They are useful for checking the embedding endpoint with Markdown and text files in `/opt/llm/rag/docs`.

The script collection is not an Open WebUI knowledge base.

```sh
./scripts/ingest.sh
./scripts/query.sh "how do we deploy vaultwarden?"
```

If documents are deleted or shortened, recreate the script collection before ingesting again. The scripts do not remove old chunks.

## normal use

```sh
./scripts/up.sh
nerdctl compose logs -f
./scripts/down.sh
```


&nbsp;

**466f724a616e6574**
