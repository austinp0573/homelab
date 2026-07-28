# speech

## resource estimates

Rough idle / typical / peak guesses. Whisper VRAM is model-dependent.

### whisper

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-5% idle | ~500 MB-1 GB RAM; GPU free when idle | model files hundreds of MB to several GB | idle |
| expected | GPU busy during transcription; some CPU for IO | ~1-3 GB RAM; VRAM model-dependent (often 1-6 GB) | audio + model artifacts | upload audio / stream results |
| high | GPU saturated on long files | larger whisper models need more VRAM | batch audio libraries | long-form / batch jobs |

VRAM depends on the whisper model size. Stop llama.cpp / ComfyUI first.

### piper

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~30-80 MB | voice models tens to hundreds of MB | idle wyoming |
| expected | 10-40% of 1 core while speaking | ~80-200 MB | voices on disk | TTS request/response audio |
| high | 1 core | ~300-500 MB | many voices installed | back-to-back TTS |

deploy path: `/opt/llm-speech`

Whisper is a GPU transcription service. Piper is a CPU Wyoming TTS service. Stop llama.cpp or ComfyUI before starting this stack.

## first run

1. Create `/opt/llm/whisper` and `/opt/llm/tts`.
2. Copy this directory to `/opt/llm-speech`.
3. Copy `.env.example` to `.env`.
4. Run `./scripts/up.sh`.
5. Run `./scripts/transcribe-test.sh /path/to/sample.wav`.

The first build downloads the ROCm PyTorch image and installs Whisper. The model cache lives in `/opt/llm/whisper`.

## use

Whisper listens on `127.0.0.1:9000` by default:

```text
POST /v1/audio/transcriptions
POST /asr
GET /health
```

Audio uploads are limited by `WHISPER_MAX_UPLOAD_MB`. Keep the endpoint on loopback unless a proxy enforces the same limit.

Piper listens on `127.0.0.1:10200` by default. For Home Assistant or another LAN Wyoming client, set `PIPER_BIND` to the host LAN address and limit that port with the firewall.

## normal use

```sh
./scripts/up.sh
nerdctl compose logs -f whisper
./scripts/down.sh
```


&nbsp;

**466f724a616e6574**
