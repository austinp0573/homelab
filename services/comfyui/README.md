# comfyui

## resource estimates

Rough idle / typical / peak guesses. GPU/VRAM is model-dependent more than anything else.

### comfyui

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-5% on CPU while idle UI | ~1-2 GB RAM process overhead; GPU mostly free | models/checkpoints often tens to hundreds of GB | UI websocket idle |
| expected | 1-4 CPU cores during gen; GPU busy | ~4-8 GB system RAM common | working outputs + models dominate disk | moderate - model load is local |
| high | many CPU threads for some nodes | system RAM 8-16 GB+; VRAM is model-dependent (often 8-24 GB) | huge model packs | batch / video / large workflows |

VRAM is almost entirely model and workflow dependent. Stop other GPU stacks first.

deploy path: `/opt/comfyui`

ComfyUI is a separate GPU workload. Stop llama.cpp, Whisper, and ebook2audiobook before starting it.

## first run

1. Copy this directory to `/opt/comfyui`.
2. Copy `compose.yml.template` to `compose.yml`.
3. Copy `.env.example` to `.env`.
4. Run `./scripts/up.sh`.
5. Open `http://127.0.0.1:8188`.

The default image is the ROCm 7.2 Ubuntu 24.04 image. The container receives `/dev/kfd` and `/dev/dri`.

## data

All persistent files live under `/opt/comfyui/data`:

```text
models/
input/
output/
user/
```

Put model files in `models`. Generated images stay in `output`.

The UI binds to loopback by default. Set `COMFYUI_BIND` to the host LAN address only when the host firewall limits access.

## normal use

```sh
./scripts/up.sh
nerdctl compose logs -f
./scripts/down.sh
```


&nbsp;

**466f724a616e6574**
