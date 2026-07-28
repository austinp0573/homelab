# minimal whisper HTTP service for local use
# OpenAI-compatible-ish transcription endpoint plus a simple /asr

import os
import tempfile
from typing import Optional

import whisper
from fastapi import FastAPI, File, Form, HTTPException, UploadFile

MODEL_NAME = os.environ.get("WHISPER_MODEL", "medium")
DEVICE = os.environ.get("WHISPER_DEVICE", "cuda")
MAX_UPLOAD_MB = int(os.environ.get("WHISPER_MAX_UPLOAD_MB", "200"))
MAX_UPLOAD_BYTES = MAX_UPLOAD_MB * 1024 * 1024

print(f"loading whisper model={MODEL_NAME} device={DEVICE}")
model = whisper.load_model(MODEL_NAME, device=DEVICE)
print("whisper ready")

app = FastAPI()


async def _save_upload(upload: UploadFile) -> str:
    suffix = os.path.splitext(upload.filename or "audio.wav")[1] or ".wav"
    path = ""

    try:
        total = 0
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            path = tmp.name
            while chunk := await upload.read(1024 * 1024):
                total += len(chunk)
                if total > MAX_UPLOAD_BYTES:
                    raise HTTPException(
                        status_code=413,
                        detail=f"audio file is larger than {MAX_UPLOAD_MB} MB",
                    )
                tmp.write(chunk)
        return path
    except Exception:
        if path and os.path.exists(path):
            os.unlink(path)
        raise


async def _transcribe(upload: UploadFile, language: Optional[str]) -> dict:
    path = await _save_upload(upload)
    try:
        kwargs = {}
        if language:
            kwargs["language"] = language
        result = model.transcribe(path, **kwargs)
    finally:
        if os.path.exists(path):
            os.unlink(path)
    return {"text": (result.get("text") or "").strip()}


@app.get("/health")
def health():
    return {"ok": True, "model": MODEL_NAME, "device": DEVICE}


@app.post("/asr")
async def asr(
    audio_file: UploadFile = File(...),
    language: Optional[str] = Form(None),
):
    return await _transcribe(audio_file, language)


@app.post("/v1/audio/transcriptions")
async def transcriptions(
    file: UploadFile = File(...),
    language: Optional[str] = Form(None),
    model: Optional[str] = Form(None),
):
    # model form field ignored; container has one loaded model
    _ = model
    out = await _transcribe(file, language)
    return {"text": out["text"]}
