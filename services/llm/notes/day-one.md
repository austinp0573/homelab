# day one

## host check

```sh
cd /opt/llm-llama-cpp
./scripts/rocm-check.sh
```

Save the output with the date, host ROCm version, and the image tag that works.

Use `benchmarks.md` to record the first model run.

## models

Put these files in `/opt/llm/models`.

- one chat model
- one coder model
- `nomic-embed-text-v1.5.Q8_0.gguf`

Start with one 20GB or smaller Q4 chat model and `CTX_SIZE=8192`.

## chat

```sh
cd /opt/llm-llama-cpp
cp .env.example .env
# set MODEL_FILE
./scripts/up.sh
./scripts/smoke.sh
```

## document QA

```sh
cd /opt/llm-rag-headless
cp .env.example .env
./scripts/up.sh
./scripts/smoke.sh

cd /opt/llm-open-webui
cp compose.yml.template compose.yml
cp .env.example .env
# set WEBUI_SECRET_KEY
./scripts/up.sh
```

Create the first Open WebUI admin account. Then set `ENABLE_SIGNUP=False` and run `./scripts/up.sh` again.

Upload files through Open WebUI Workspace. Use a knowledge base for repeated document QA.

## switching GPU jobs

```sh
cd /opt/llm-llama-cpp
./scripts/down.sh

cd /opt/comfyui
./scripts/up.sh
```

The same pattern applies to Whisper and ebook2audiobook.
