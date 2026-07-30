# local llm

R9700 box:

- Ubuntu 24.04
- ROCm
- Radeon AI Pro R9700 with 32GB VRAM
- 64GB system RAM

The normal setup is llama.cpp, Open WebUI, Qdrant, and the CPU embedding server.

## start here

1. Read `notes/day-one.md`.
2. Start `llama-cpp`.
3. Start `rag-headless`.
4. Start `../open-webui`.

Open WebUI is the normal chat and document-QA UI. It talks to llama.cpp, Qdrant, and the embedding service on the internal `llm-backend` network.

## GPU rule

Only one GPU-heavy stack runs at a time.

- llama.cpp
- Whisper
- ComfyUI
- ebook2audiobook

Stop the active stack before starting another one.

Qdrant, the CPU embedding server, Open WebUI, Piper, and Pi can run next to llama.cpp.

## directories

```text
/opt/llm/models
/opt/llm/rag/docs
/opt/llm/rag/qdrant
/opt/llm/whisper
/opt/llm/tts
/opt/llm/ebooks
/opt/llm/audiobooks
/opt/llm/ebook-models
/opt/llm/ebook-voices
```

## stacks

- `llama-cpp` is the OpenAI-compatible inference API.
- `rag-headless` is Qdrant and the CPU embedding API for Open WebUI.
- `speech` is Whisper and Piper.
- `ebook2audiobook` makes audiobooks with a separate GPU workload.
- `rag-ui` is an optional AnythingLLM test setup.
- `pi-agent` is parked for now.
- `notes` has the run notes.

ComfyUI lives in `../comfyui`. Open WebUI lives in `../open-webui`.


&nbsp;

**466f724a616e6574**
