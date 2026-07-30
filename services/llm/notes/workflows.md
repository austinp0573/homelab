# workflows

## chat

1. `cd /opt/llm-llama-cpp && ./scripts/up.sh`
2. smoke: `./scripts/smoke.sh`
3. Open WebUI -> `http://127.0.0.1:3000`

```sh
curl -s http://127.0.0.1:8080/v1/models
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"hi"}],"max_tokens":64}'
```

## coding with Pi

1. llama.cpp up with a coder GGUF
2. `cd /opt/llm-pi-agent && ./scripts/build.sh` (once)
3. `./scripts/run.sh /path/to/project`

Pi talks to `http://host.docker.internal:8080/v1` (or the LAN IP you set in `config/models.json`).

## RAG ingest then chat

Open WebUI path:

1. start `rag-headless` for Qdrant and CPU embeddings
2. start llama.cpp
3. start Open WebUI
4. upload files in Workspace
5. add files to a knowledge base
6. attach that knowledge base to a chat

Open WebUI handles Markdown, text, PDF, EPUB, and one-off web pages. Use `#https://example.com/page` at the start of a chat to load a page.

The plain text scripts in `rag-headless` use a separate collection:

```sh
cd /opt/llm-rag-headless
./scripts/ingest.sh
./scripts/query.sh "what do we say about X?"
```

## speech

1. stop llama/comfy if you want full VRAM for large-v3
2. `cd /opt/llm-speech && ./scripts/up.sh`
3. STT: `POST http://<host>:9000/asr` (see speech README)
4. Piper listens on 10200 (wyoming). for OpenAI-style TTS later, wrap or swap; Piper alone is enough for HA / wyoming clients.

## ebook2audiobook

1. stop llama/comfy/speech
2. `cd /opt/llm-ebook2audiobook && ./scripts/up.sh`
3. use the local UI or run `./scripts/convert.sh book.epub`

## ComfyUI

1. stop llama/speech/ebook2audiobook
2. `cd /opt/comfyui && ./scripts/up.sh`
3. open `http://127.0.0.1:8188`

## switching

always:

```sh
nerdctl compose down
```

in the active project before starting another GPU project. no shared compose profiles on purpose - keeps mental model dumb.
