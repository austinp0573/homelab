# rag-ui

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### anythingllm

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 2-5% | ~200-400 MB | workspace data + embeddings on disk | idle UI |
| expected | 10-30% | ~500 MB-1.5 GB | grows with documents / vector cache | chat + doc ingest |
| high | 1-2 cores | ~2-4 GB | multi-GB document sets | large ingest or concurrent users |

If this talks to an external LLM, inference cost is on that backend.

deploy path: `/opt/llm-rag-ui`

AnythingLLM is an optional separate document UI. The normal setup uses Open WebUI with Qdrant instead. Do not run both document workflows unless there is a specific reason to compare them.

## first run

1. Start llama.cpp so `llm-backend` exists.
2. Copy this directory to `/opt/llm-rag-ui`.
3. Copy `.env.example` to `.env`.
4. Run `./scripts/up.sh`.
5. Open `http://127.0.0.1:3001`.
6. Create an admin account in the first-run wizard.

The container reaches llama.cpp at `http://llama-cpp:8080/v1` on the internal network. The UI binds to loopback by default.

`SYS_ADMIN` is intentionally not granted. Browser scraping may need extra Chromium permissions; add those only if that feature is actually needed.

## normal use

```sh
./scripts/up.sh
nerdctl compose logs -f
./scripts/down.sh
```


&nbsp;

**466f724a616e6574**
