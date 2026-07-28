# llama-cpp

## resource estimates

Rough idle / typical / peak guesses. Almost everything here is model/context dependent.

### llama-cpp

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-5% with model loaded but idle | process overhead hundreds of MB; model weights dominate RAM/VRAM | GGUF files: ~4-8 GB for 7-9B Q4, much more for larger | idle HTTP |
| expected | 1+ GPU heavily used while generating; CPU for tokenizer/scheduling | RAM/VRAM ~= weights + KV cache (context length matters a lot) | one or more GGUFs on disk | prompt/response tokens over lan |
| high | GPU saturated; CPU can spike on prompt eval | large context / parallel slots can add multiple GB of KV | many models on disk | long context, multi-slot, or speculative decoding |

Weights + KV cache dominate. A 7B Q4 often needs ~5-8 GB VRAM at modest context; bigger models and longer context climb fast.

deploy path: `/opt/llm-llama-cpp`

This is the only LLM inference server on the box. Open WebUI and optional local tools use it over the `llm-backend` network.

## first run

1. Install the host ROCm stack.
2. Run `./scripts/rocm-check.sh`.
3. Create `/opt/llm/models`.
4. Put one GGUF in that directory.
5. Copy `.env.example` to `.env`.
6. Set `MODEL_FILE` to the GGUF filename.
7. Run `./scripts/up.sh`.
8. Run `./scripts/smoke.sh`.

Start with `CTX_SIZE=8192`. Keep one chat model loaded at a time. The R9700 has room for a 20GB Q4 model and useful context headroom, but the real limit depends on the model and prompt size.

## network

The API binds to `127.0.0.1` by default. It is also reachable to containers on `llm-backend` as:

```text
http://llama-cpp:8080/v1
```

Open WebUI uses that internal address. Do not change `HOST_BIND` unless another host service needs the API.

## ROCm

The container needs `/dev/kfd`, `/dev/dri`, `video`, `render`, and `ipc: host`.

The default image is the upstream ROCm image. Once a model starts cleanly, record the working image tag, host ROCm version, `rocminfo` output, model, context size, and tokens per second in `../notes/`.

Leave `HSA_OVERRIDE_GFX_VERSION` empty unless the host check and a failed start show it is needed.

## normal use

```sh
./scripts/up.sh
./scripts/smoke.sh
nerdctl compose logs -f
./scripts/down.sh
```

To switch models, stop the stack, update `MODEL_FILE`, and start it again.


&nbsp;

**466f724a616e6574**
