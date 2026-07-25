# open-webui

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### open-webui

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 2-5% | ~200-400 MB | sqlite + uploads; starts hundreds of MB | idle UI |
| expected | 10-40% | ~500 MB-1.5 GB | chat history / docs can reach multi-GB | chat UI traffic; embeddings hit rag-headless |
| high | 1-2 cores | ~2-4 GB | large doc libraries / many users | big ingest or many concurrent chats |

Token generation cost is on llama.cpp. Vectors/embeddings are on rag-headless.

deploy path: `/opt/llm-open-webui`

Open WebUI is the browser UI for llama.cpp and the normal document-QA UI. It uses Qdrant and the CPU embedding service from `services/llm/rag-headless`.

## first run

1. Copy this directory to `/opt/llm-open-webui`.
2. Copy `compose.yml.template` to `compose.yml`.
3. Copy `.env.example` to `.env`.
4. Replace `WEBUI_SECRET_KEY` with `openssl rand -hex 32`.
5. Start `/opt/llm-rag-headless` so Qdrant and embeddings are available.
6. Start llama.cpp.
7. Run `./scripts/up.sh`.
8. Open `http://127.0.0.1:3000`.
9. Create the first admin account.
10. Set `ENABLE_SIGNUP=False` in `.env` and run `./scripts/up.sh` again.

The default port only listens on loopback. To use it from the LAN, set `WEBUI_BIND` to the host LAN address and limit access with the host firewall.

## document QA

Upload Markdown, text, PDF, and EPUB files in Workspace, then add them to a knowledge base. Open WebUI stores the vectors in Qdrant and uses the local embedding service.

For a web page, start a chat prompt with `#https://example.com/page`, select the parsed link, then send the question.

The embedding server needs to stay up while using document QA. It is CPU-only and does not conflict with llama.cpp.

## normal use

```sh
./scripts/up.sh
nerdctl compose logs -f
./scripts/down.sh
```


&nbsp;

**466f724a616e6574**
