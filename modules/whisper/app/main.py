"""
Whisper STT FastAPI Service
OpenAI-compatible API endpoint for speech-to-text transcription
"""
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
from faster_whisper import WhisperModel
import tempfile
import os
from pathlib import Path
from typing import Optional
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Whisper STT API",
    description="OpenAI-compatible speech-to-text API using faster-whisper",
    version="0.1.0"
)

# Configuration from environment
MODEL_SIZE = os.getenv("WHISPER_MODEL", "base")
DEVICE = "cuda" if os.getenv("CUDA_AVAILABLE") == "true" else "cpu"
COMPUTE_TYPE = "float16" if DEVICE == "cuda" else "int8"

# Global model instance
model = None


@app.on_event("startup")
async def startup_event():
    """Load Whisper model on application startup"""
    global model
    logger.info(f"Loading Whisper model: {MODEL_SIZE} on {DEVICE} with {COMPUTE_TYPE}")
    model = WhisperModel(
        model_size_or_path=MODEL_SIZE,
        device=DEVICE,
        compute_type=COMPUTE_TYPE,
        download_root="/models"  # Persistent volume mount
    )
    logger.info("Model loaded successfully")


@app.post("/v1/audio/transcriptions")
async def transcribe_audio(
    file: UploadFile = File(..., description="Audio file to transcribe"),
    model_name: str = Form("whisper-1", description="Model to use (OpenAI compatibility)", alias="model"),
    language: Optional[str] = Form(None, description="Language code (e.g., 'en', 'es')"),
    prompt: Optional[str] = Form(None, description="Optional text to guide transcription"),
    response_format: str = Form("json", description="Response format (json, text, srt, vtt)"),
    temperature: float = Form(0.0, description="Sampling temperature (0.0 - 1.0)")
):
    """
    Transcribe audio to text using Whisper model.

    OpenAI-compatible endpoint that accepts audio files and returns transcriptions.
    Supports multiple audio formats (mp3, wav, m4a, ogg, etc.)
    """
    if not file:
        raise HTTPException(status_code=400, detail="No audio file provided")

    # Save uploaded file temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix=Path(file.filename).suffix) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        logger.info(f"Transcribing audio file: {file.filename} (language: {language or 'auto'})")

        # Transcribe audio using faster-whisper
        segments, info = model.transcribe(
            tmp_path,
            language=language,
            initial_prompt=prompt,
            temperature=temperature,
            vad_filter=True,  # Voice Activity Detection to filter silence
            vad_parameters=dict(min_silence_duration_ms=500)
        )

        # Collect all segments into full transcription
        transcription = " ".join([segment.text.strip() for segment in segments])

        logger.info(f"Transcription complete: {len(transcription)} characters, language: {info.language}")

        # Return OpenAI-compatible response
        if response_format == "text":
            return transcription
        else:
            return JSONResponse({
                "text": transcription,
                "language": info.language,
                "duration": round(info.duration, 2),
                "language_probability": round(info.language_probability, 2)
            })

    except Exception as e:
        logger.error(f"Transcription error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

    finally:
        # Cleanup temporary file
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


@app.get("/health")
async def health_check():
    """Health check endpoint for container monitoring"""
    return {
        "status": "healthy",
        "model": MODEL_SIZE,
        "device": DEVICE,
        "compute_type": COMPUTE_TYPE
    }


@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "service": "Whisper STT API",
        "version": "0.1.0",
        "model": MODEL_SIZE,
        "device": DEVICE,
        "endpoint": "/v1/audio/transcriptions",
        "docs": "/docs"
    }