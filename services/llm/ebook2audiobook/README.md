# ebook2audiobook

## resource estimates

Rough idle / typical / peak guesses. GPU use is model-dependent.

### ebook2audiobook

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-5% waiting for jobs | ~1-2 GB RAM; GPU idle | models + output audio can be many GB | idle UI |
| expected | multi-core during conversion; GPU busy if ROCm path is used | ~4-8 GB RAM common | per-book outputs add up | download/upload of books and audio |
| high | saturates CPU/GPU for long jobs | 8-16 GB RAM; VRAM model-dependent | large libraries | batch converting big books |

GPU/VRAM depends on the TTS/ASR models in use. Stop other GPU stacks first.

deploy path: `/opt/llm-ebook2audiobook`

This is the ROCm container for [ebook2audiobook](https://github.com/DrewThomasson/ebook2audiobook). It is a separate GPU workload. Stop llama.cpp, Whisper, and ComfyUI before using it.

## first run

1. Copy this directory to `/opt/llm-ebook2audiobook`.
2. Copy `.env.example` to `.env`.
3. Run `./scripts/up.sh`.
4. Open `http://127.0.0.1:7860`.
5. Upload a book or place it in `/opt/llm/ebooks`.

The first conversion downloads TTS models into `/opt/llm/ebook-models`.

## headless conversion

Put a file in `/opt/llm/ebooks`, then run:

```sh
./scripts/convert.sh my-book.epub
```

The output is written under `/opt/llm/audiobooks`.

Pass upstream options after the filename when needed:

```sh
./scripts/convert.sh my-book.epub --language eng
```

## data

```text
/opt/llm/ebooks
/opt/llm/audiobooks
/opt/llm/ebook-models
/opt/llm/ebook-voices
/opt/llm/ebook-tmp
```

The GUI binds to loopback by default. Set `EBOOK_BIND` to the host LAN address only when access is limited by the firewall.

## normal use

```sh
./scripts/up.sh
./scripts/down.sh
```


&nbsp;

**466f724a616e6574**
