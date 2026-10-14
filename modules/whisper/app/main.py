"""
Whisper STT FastAPI Service
OpenAI-compatible API endpoint for speech-to-text transcription
Supports dynamic model loading based on request parameters
"""
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
from faster_whisper import WhisperModel
import hashlib
import tempfile
import threading
import os
from collections import OrderedDict
from pathlib import Path
from typing import Optional, Dict
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Whisper STT API",
    description="OpenAI-compatible speech-to-text API with dynamic model selection",
    version="0.2.0"
)

# Configuration from environment
DEFAULT_MODEL_SIZE = os.getenv("WHISPER_MODEL", "base")
DEVICE = "cuda" if os.getenv("CUDA_AVAILABLE", "false").lower() == "true" else "cpu"
COMPUTE_TYPE = "float16" if DEVICE == "cuda" else "int8"
MODELS_DIR = "/models"

# Available model sizes
AVAILABLE_MODELS = ["tiny", "base", "small", "medium", "large-v2", "large-v3", "large-v3-turbo"]

# faster-whisper retries a segment at the next temperature when its output is too
# repetitive (compression_ratio_threshold) or too unlikely. A single fixed temperature
# disables that retry, which is how a long recording ends in "像 像 像 ..." forever.
DEFAULT_TEMPERATURES = (0.0, 0.2, 0.4, 0.6, 0.8, 1.0)

# Model cache: {model_size: WhisperModel instance}
model_cache: Dict[str, WhisperModel] = {}

# A long recording on CPU outlasts n8n's 2-minute schedule, so the next run sends the
# same file again. Identical requests share one transcription: the second waits on the
# first's lock and then reads its result instead of transcribing the file twice.
RESULT_CACHE_SIZE = 32
_result_cache: "OrderedDict[str, dict]" = OrderedDict()
_request_locks: Dict[str, threading.Lock] = {}
_registry_lock = threading.Lock()


# Locks are never dropped: removing one while a request waits on it would let a third
# identical request run in parallel. One Lock per distinct request is a few bytes.
def _request_lock(key: str) -> threading.Lock:
    with _registry_lock:
        return _request_locks.setdefault(key, threading.Lock())


def get_or_load_model(model_size: str) -> WhisperModel:
    """
    Get cached model or load new one.
    Models are loaded on-demand and cached for reuse.
    """
    if model_size not in AVAILABLE_MODELS:
        raise ValueError(f"Invalid model size. Available: {', '.join(AVAILABLE_MODELS)}")

    if model_size not in model_cache:
        logger.info(f"Loading Whisper model: {model_size} on {DEVICE} with {COMPUTE_TYPE}")
        model_cache[model_size] = WhisperModel(
            model_size_or_path=model_size,
            device=DEVICE,
            compute_type=COMPUTE_TYPE,
            download_root=MODELS_DIR
        )
        logger.info(f"Model {model_size} loaded and cached successfully")

    return model_cache[model_size]


@app.on_event("startup")
async def startup_event():
    """Preload default model on application startup"""
    logger.info(f"Starting Whisper STT API - Default model: {DEFAULT_MODEL_SIZE}")
    logger.info(f"Device: {DEVICE}, Compute type: {COMPUTE_TYPE}")
    logger.info(f"Available models: {', '.join(AVAILABLE_MODELS)}")

    # Preload default model
    try:
        get_or_load_model(DEFAULT_MODEL_SIZE)
        logger.info("Default model preloaded successfully")
    except Exception as e:
        logger.error(f"Failed to preload default model: {e}")
        # Don't fail startup - models can be loaded on-demand


# A plain def runs in FastAPI's threadpool, so /health keeps answering while a long
# file is being transcribed instead of the whole event loop blocking on it.
@app.post("/v1/audio/transcriptions")
def transcribe_audio(
    file: UploadFile = File(..., description="Audio file to transcribe"),
    model_name: str = Form("whisper-1", description="Model to use (OpenAI compatibility)", alias="model"),
    whisper_model: Optional[str] = Form(None, description="Whisper model size (tiny, base, small, medium, large-v3, large-v3-turbo)"),
    language: Optional[str] = Form(None, description="Language code (e.g., 'en', 'es')"),
    prompt: Optional[str] = Form(None, description="Optional text to guide transcription"),
    response_format: str = Form("json", description="Response format (json, text, srt, vtt)"),
    temperature: Optional[float] = Form(None, description="Sampling temperature (0.0 - 1.0); omit to allow fallback")
):
    """
    Transcribe audio to text using Whisper model.

    OpenAI-compatible endpoint that accepts audio files and returns transcriptions.
    Supports multiple audio formats (mp3, wav, m4a, ogg, etc.)

    **New**: Supports dynamic model selection via 'whisper_model' parameter.
    If not specified, uses the default model from WHISPER_MODEL environment variable.

    Available models: tiny, base, small, medium, large-v2, large-v3, large-v3-turbo
    """
    if not file:
        raise HTTPException(status_code=400, detail="No audio file provided")

    # Determine which model to use
    selected_model = whisper_model or DEFAULT_MODEL_SIZE

    # Validate and load model
    try:
        model = get_or_load_model(selected_model)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Failed to load model {selected_model}: {e}")
        raise HTTPException(status_code=500, detail=f"Model loading failed: {str(e)}")

    content = file.file.read()
    key = hashlib.sha256(
        repr((hashlib.sha256(content).hexdigest(), selected_model, language, prompt, temperature)).encode()
    ).hexdigest()

    with _request_lock(key):
        with _registry_lock:
            result = _result_cache.get(key)
        if result is None:
            result = _transcribe(model, content, file.filename, selected_model, language, prompt, temperature)
            with _registry_lock:
                _result_cache[key] = result
                while len(_result_cache) > RESULT_CACHE_SIZE:
                    _result_cache.popitem(last=False)
        else:
            logger.info(f"Reusing transcription of {file.filename} from an identical earlier request")

    # Return OpenAI-compatible response
    if response_format == "text":
        return result["text"]
    return JSONResponse(result)


def _transcribe(model, content, filename, selected_model, language, prompt, temperature) -> dict:
    # Save uploaded file temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix=Path(filename).suffix) as tmp:
        tmp.write(content)
        tmp_path = tmp.name

    try:
        logger.info(f"Transcribing {filename} with model={selected_model}, language={language or 'auto'}")

        # Transcribe audio using faster-whisper
        segments, info = model.transcribe(
            tmp_path,
            language=language,
            initial_prompt=prompt,
            temperature=DEFAULT_TEMPERATURES if temperature is None else temperature,
            # Feeding each segment's text into the next one is what lets a single
            # wrong segment repeat for the rest of the file.
            condition_on_previous_text=False,
            vad_filter=True,  # Voice Activity Detection to filter silence
            vad_parameters=dict(min_silence_duration_ms=500)
        )

        # Collect all segments into full transcription
        transcription = " ".join([segment.text.strip() for segment in segments])

        logger.info(f"Transcription complete: {len(transcription)} chars, lang={info.language}, model={selected_model}")

        return {
            "text": transcription,
            "language": info.language,
            "duration": round(info.duration, 2),
            "language_probability": round(info.language_probability, 2),
            "model_used": selected_model  # Include which model was used
        }

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
        "default_model": DEFAULT_MODEL_SIZE,
        "device": DEVICE,
        "compute_type": COMPUTE_TYPE,
        "loaded_models": list(model_cache.keys()),
        "available_models": AVAILABLE_MODELS
    }


@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "service": "Whisper STT API",
        "version": "0.2.0",
        "default_model": DEFAULT_MODEL_SIZE,
        "device": DEVICE,
        "available_models": AVAILABLE_MODELS,
        "loaded_models": list(model_cache.keys()),
        "endpoint": "/v1/audio/transcriptions",
        "docs": "/docs"
    }