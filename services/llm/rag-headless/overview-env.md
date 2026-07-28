# rag-headless env

Qdrant + CPU embed server for Open WebUI (and scripts). do **not** `ingest.sh` into Open WebUI–owned collections.

## compose `.env`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `llm-rag-headless` | Compose project wrapping both Qdrant and the embed server. Keep stable so the qdrant data dir association and container names stay predictable. Renaming mid-flight makes `down` miss resources and you will start a second embed on 8081 by accident. Scripts that call compose in this directory assume this project name. |
| `RESTART_POLICY` | `unless-stopped` | Applied to both services so RAG stays up with Open WebUI. Embed is CPU-only here, so leaving it running beside ROCm llama is fine — unlike Whisper. If you stop the stack, Open WebUI RAG calls fail hard until it is back. Do not use `no` unless you are deliberately doing one-shot experiments. |
| `QDRANT_CONTAINER_NAME` | `llm-qdrant` | DNS name Open WebUI uses in `QDRANT_URI`. Change one without the other and RAG looks "configured" while every upsert fails. Keep it unique on `llm-backend`. I never let compose assign a random name for this one. |
| `EMBED_CONTAINER_NAME` | `llm-embed` | DNS name for the llama.cpp embed server on `llm-backend`. Open WebUI `RAG_OPENAI_API_BASE_URL` points at `http://llm-embed:8080/v1`. Host publish is on 8081; container-to-container still uses 8080. Renaming breaks RAG embeddings with confusing OpenAI-client errors. |
| `LLM_NETWORK` | `llm-backend` | Shared external network with llama-cpp and Open WebUI. Qdrant and embed must be reachable by container DNS from the WebUI container. Host binds are for debugging only. Missing network = compose create failure, not a silent fallback. |
| `QDRANT_BIND` | `127.0.0.1` | Host publish bind for Qdrant HTTP/gRPC. Loopback keeps the vector DB off the LAN while Open WebUI uses Docker DNS. Opening `0.0.0.0` exposes an unauthenticated Qdrant by default — bad idea on a shared network. Use port-forward if you need remote admin. |
| `QDRANT_HOST_PORT` | `6333` | Host → Qdrant HTTP API. Handy for `curl` collections from the host and for scripts run outside compose. Peers on `llm-backend` use `llm-qdrant:6333`, not this host port. Collides with any other Qdrant you forgot was running. |
| `QDRANT_GRPC_PORT` | `6334` | Host publish for Qdrant gRPC. Most of this lab talks HTTP; gRPC is for clients that prefer it or for debugging. Still bind loopback. Leaving it published wide is the same exposure class as HTTP. |
| `EMBED_BIND` | `127.0.0.1` | Host bind for the embed server publish. Loopback for host-side `ingest.sh` against localhost:8081. Open WebUI should not use the host bind — it uses `llm-embed` DNS. Same LAN exposure warning as Qdrant if you open it up. |
| `EMBED_HOST_PORT` | `8081` | Host port mapped to embed container `:8080`. Offset from llama's 8080 so both can publish on one host. Forgetting the offset and curling 8080 hits the chat model, not embeddings — vectors will look insane if you somehow force that path. Inside the network, always `:8080` on `llm-embed`. |
| `QDRANT_IMAGE` | `qdrant/qdrant:v1.13.2` | Pinned Qdrant version. Storage format can shift across majors; pin and upgrade with a backup of `QDRANT_DATA_DIR`. Floating tags recreate into surprise migrations. Match client libraries loosely to this generation if you script against the API. |
| `EMBED_IMAGE` | `ghcr.io/ggml-org/llama.cpp:server` | CPU llama.cpp server image (compose runs with `-ngl 0`). Intentionally not the ROCm tag so it can sit beside GPU llama without fighting the accelerator. Using the ROCm image here invites GPU exclusivity bugs for no gain. Keep embed and chat as separate containers. |
| `MODELS_DIR` | `/opt/llm/models` | Host GGUF tree mounted for the embed model file. Same store as chat weights is fine; files differ. Embed model must be present as `EMBED_MODEL_FILE`. Mount issues show up as embed server crash loops, not Qdrant errors. |
| `QDRANT_DATA_DIR` | `/opt/llm/rag/qdrant` | Persistent Qdrant storage on the host. This is the RAG memory — lose it and collections are gone. Do not point Open WebUI and a second Qdrant at overlapping paths. Stop the container before copying/moving this directory. |
| `DOCS_DIR` | `/opt/llm/rag/docs` | Corpus used by `ingest.sh` only, not mounted into Open WebUI by this stack. Keep in sync with what you intend to index. ingest into a collection Open WebUI already owns and you will corrupt the product's expectations — use a script collection name, not WebUI's. If you need WebUI-native docs, upload in the UI or use its own pipelines instead of this script path. |
| `EMBED_MODEL_FILE` | `nomic-embed-text-v1.5.Q8_0.gguf` | Embedding GGUF loaded by the CPU server. Must match Open WebUI `RAG_EMBEDDING_MODEL` and `EMBED_VECTOR_SIZE` (768 for this nomic build). Swap models only with a fresh collection; dimension mismatches fail upserts. Chat GGUFs are not embed models — do not reuse `MODEL_FILE` from llama-cpp. |
| `EMBED_CTX_SIZE` | `2048` | Context length for the embed server (`-c`). Chunker settings should stay under this or embeddings truncate mid-chunk. Bigger ctx costs RAM/CPU on the embed box, not GPU. Align with `CHUNK_SIZE` practice, not with chat `CTX_SIZE`. |
| `EMBED_THREADS` | `8` | `-t` CPU threads for embedding. Set near physical cores you are willing to give away; too high stalls the host under ingest. Too low makes bulk ingest crawl. Does not affect Qdrant much — this is pure embed throughput. |

## script-only (ingest/query)

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `QDRANT_COLLECTION` | `lab` | Collection name for shell ingest/query helpers. Keep this away from whatever Open WebUI creates for its own RAG — dual writers on one collection is how you get mystery deletes. Create the collection with the right vector size before bulk upsert. Renaming means a new empty collection unless you migrate. |
| `EMBED_VECTOR_SIZE` | `768` | Vector dimensionality declared when creating the collection. **Must** match the embed model output (nomic-embed Q8 here is 768). Wrong size fails at upsert or, worse, lets you create a collection you can never fill correctly. Change model ⇒ new collection, do not "fix" the number in place. |
| `CHUNK_SIZE` | `800` | Character/token-ish chunk length used by ingest scripts when splitting documents. Larger chunks mean fewer vectors but mushier retrieval; smaller means more Qdrant points and cost. Stay comfortably under `EMBED_CTX_SIZE`. Re-ingest after changing or old/new chunk schemes coexist badly. |
| `CHUNK_OVERLAP` | `100` | Overlap between consecutive chunks so sentences on boundaries are not lost. Too high duplicates content and bloats the collection; too low drops context at splits. Pair with `CHUNK_SIZE` rather than tuning alone. Re-ingest after changes same as chunk size. |
