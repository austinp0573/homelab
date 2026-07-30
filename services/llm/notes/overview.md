# overview

box: ubuntu 24.04 server, ROCm, AMD AI Pro R9700 (32GB VRAM), 64GB DDR4.

goal: local LLM work that stays inside VRAM. system RAM is slow enough that partial offload feels bad, so models need to fit on the card.

## stack roles

- `llama-cpp` is the only inference server.
- `open-webui` is the normal browser chat and document-QA UI.
- `rag-headless` is Qdrant plus a CPU embedding server for Open WebUI.
- `speech` is Whisper and Piper when I need transcription or voice output.
- `ebook2audiobook` is a separate GPU TTS workload.
- `comfyui` is a separate GPU image workload.
- `rag-ui` is an optional AnythingLLM comparison setup.
- `pi-agent` is parked until the normal chat and coding workflow is settled.

## ROCm note

The R9700 target is `gfx1201`. Record the working host ROCm version, llama image, model, context size, and benchmark after the first clean run.

Check the host before starting a GPU stack:

```sh
cd /opt/llm-llama-cpp
./scripts/rocm-check.sh
```

Leave `HSA_OVERRIDE_GFX_VERSION` empty unless a failed start shows it is needed.

## network

`llm-backend` is an internal nerdctl network.

- Open WebUI reaches llama.cpp at `http://llama-cpp:8080/v1`.
- Open WebUI reaches Qdrant at `http://llm-qdrant:6333`.
- Open WebUI reaches embeddings at `http://llm-embed:8080/v1`.

The host ports bind to loopback by default. Change a bind address only when the host firewall limits the service to the intended LAN clients.
