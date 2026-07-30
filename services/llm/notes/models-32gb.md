# models that fit in 32GB VRAM

rule of thumb: leave headroom for context KV. a model that "fits" at 2k context can OOM at 32k. start with ctx 8192, raise until it hurts.

sizes below are approximate loaded VRAM for llama.cpp with `--n-gpu-layers 999` (full offload). Q4_K_M unless noted.

## chat / general

| model (GGUF) | ~VRAM | notes |
|--------------|-------|-------|
| Qwen3-32B Q4_K_M | ~20GB | normal chat model |
| Qwen2.5-32B-Instruct Q4_K_M | ~20GB | stable fallback |
| Qwen2.5-14B-Instruct Q4_K_M | ~10GB | quick tests and light chat |
| Llama-3.1-8B-Instruct Q5_K_M | ~6GB | fast, fine for light chat |
| Llama-3.3-70B-Instruct Q3_K_M | ~32GB | tight; use short ctx or skip |
| Gemma-3-27B-IT Q4_K_M | ~17GB | good quality/speed trade |

prefer staying at or under ~24GB weights so 8k-16k ctx still fits.

## coding

| model | ~VRAM | notes |
|-------|-------|-------|
| Qwen3-Coder-30B-A3B-Instruct Q4_K_M | ~19GB | normal coder model |
| Qwen2.5-Coder-32B-Instruct Q4_K_M | ~20GB | stable fallback |
| Qwen2.5-Coder-14B-Instruct Q4_K_M | ~10GB | quick tests |
| Devstral / other 24B coder Q4 | ~14-16GB | try if you like the family |

for code, try the 30B coder before adding another agent layer.

## embeddings (RAG)

The normal embedding server runs on CPU. It stays up with llama.cpp and keeps document QA simple.

| model | runtime |
|-------|---------|
| nomic-embed-text-v1.5 Q8_0 | CPU |
| bge-m3 Q4_K_M | CPU |

rag-headless defaults to nomic. Do not change the embedding model after documents are indexed without reindexing the knowledge base.

## speech

| model | ~VRAM |
|-------|-------|
| whisper medium | ~1.5GB |
| whisper large-v3 | ~3GB |

Piper TTS is CPU. leave it that way.

## image (ComfyUI, separate)

SDXL / Flux weights live under `/opt/comfyui/data/models`. not managed here. same GPU exclusivity rule.

## download pattern

put GGUFs in `/opt/llm/models/`. example:

```sh
mkdir -p /opt/llm/models
# huggingface-cli download <repo> <file.gguf> --local-dir /opt/llm/models
```

set `MODEL_FILE` in the llama-cpp `.env` to the filename only (compose mounts the directory).
