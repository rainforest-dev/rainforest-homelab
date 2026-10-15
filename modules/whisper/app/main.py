"""
Whisper STT FastAPI Service
OpenAI-compatible API endpoint for speech-to-text transcription
Supports dynamic model loading based on request parameters
"""
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
from faster_whisper import WhisperModel
from opencc import OpenCC
import hashlib
import re
import subprocess
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

# Available model sizes. fun-asr-nano is FunASR's LLM-based recogniser, not a Whisper
# size; it scored 12/14 on medical terms in a Mandarin clinic recording where
# large-v3-turbo scored 7/14 (2026-10-15 comparison).
FUN_ASR_NANO = "fun-asr-nano"
FUN_ASR_NANO_ID = "FunAudioLLM/Fun-ASR-Nano-2512"
AVAILABLE_MODELS = ["tiny", "base", "small", "medium", "large-v2", "large-v3", "large-v3-turbo", FUN_ASR_NANO]

# faster-whisper retries a segment at the next temperature when its output is too
# repetitive (compression_ratio_threshold) or too unlikely. A single fixed temperature
# disables that retry, which is how a long recording ends in "像 像 像 ..." forever.
DEFAULT_TEMPERATURES = (0.0, 0.2, 0.4, 0.6, 0.8, 1.0)

# initial_prompt only steers the first 30-second window, so a long Mandarin recording
# drifts into Simplified Chinese partway through. Convert Chinese output to Traditional
# with Taiwan phrasing after decoding instead.
_s2twp = OpenCC("s2twp")

# Model cache: {model_size: loaded model}. Holds one model at a time: turbo and
# fun-asr-nano together do not fit the container's memory limit.
model_cache: Dict[str, object] = {}

# A unit of 1-8 non-digit characters repeated five or more times in a row. Fun-ASR-Nano can
# emit a thousand "嗯。" for a quiet stretch, and Whisper ends a bad file in "像 像 像".
_REPEAT_RE = re.compile(r"([^0-9]{1,8}?)(?:\s*\1){4,}", re.DOTALL)
_CJK_RE = re.compile(r"[\u4e00-\u9fff]")


def collapse_repeats(text: str) -> str:
    """Keep one copy of any run of five or more identical short units."""
    return _REPEAT_RE.sub(r"\1", text)

# A long recording on CPU outlasts n8n's 2-minute schedule, so the next run sends the
# same file again. Identical requests share one transcription: the second waits on the
# first's lock and then reads its result instead of transcribing the file twice.
RESULT_CACHE_SIZE = 32
_result_cache: "OrderedDict[str, dict]" = OrderedDict()
_request_locks: Dict[str, threading.Lock] = {}
_registry_lock = threading.Lock()
# One decode at a time. n8n sends a run's files in parallel, and two large-v3-turbo
# decodes side by side could exceed the container's memory limit.
_transcribe_lock = threading.Lock()


# Locks are never dropped: removing one while a request waits on it would let a third
# identical request run in parallel. One Lock per distinct request is a few bytes.
def _request_lock(key: str) -> threading.Lock:
    with _registry_lock:
        return _request_locks.setdefault(key, threading.Lock())


_model_load_lock = threading.Lock()


def _load_fun_asr_nano():
    # Imported here so a whisper-only container never pays for loading torch.
    from funasr import AutoModel

    # Recordings run to tens of minutes and the model takes about 30 seconds of audio
    # per pass, so the VAD cuts the file first.
    return AutoModel(
        model=FUN_ASR_NANO_ID,
        vad_model="fsmn-vad",
        vad_kwargs={"max_single_segment_time": 30000},
        device="cuda" if DEVICE == "cuda" else "cpu",
        disable_update=True,
    )


def get_or_load_model(model_size: str):
    """
    Get cached model or load new one.
    Loading a different model drops the one already loaded.
    """
    if model_size not in AVAILABLE_MODELS:
        raise ValueError(f"Invalid model size. Available: {', '.join(AVAILABLE_MODELS)}")

    with _model_load_lock:
        if model_size not in model_cache:
            model_cache.clear()
            if model_size == FUN_ASR_NANO:
                logger.info(f"Loading {FUN_ASR_NANO_ID} on {DEVICE}")
                model_cache[model_size] = _load_fun_asr_nano()
            else:
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

    if selected_model not in AVAILABLE_MODELS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid model size. Available: {', '.join(AVAILABLE_MODELS)}",
        )

    content = file.file.read()
    key = hashlib.sha256(
        repr((hashlib.sha256(content).hexdigest(), selected_model, language, prompt, temperature)).encode()
    ).hexdigest()

    with _request_lock(key):
        with _registry_lock:
            result = _result_cache.get(key)
        if result is None:
            with _transcribe_lock:
                # Loaded under the decode lock so a model is never swapped out
                # while another request is still decoding with it.
                try:
                    model = get_or_load_model(selected_model)
                except Exception as e:
                    logger.error(f"Failed to load model {selected_model}: {e}")
                    raise HTTPException(status_code=500, detail=f"Model loading failed: {str(e)}")
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

        if selected_model == FUN_ASR_NANO:
            return _transcribe_fun_asr_nano(model, tmp_path, selected_model)

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
        transcription = collapse_repeats(" ".join([segment.text.strip() for segment in segments]))
        if info.language == "zh":
            transcription = _s2twp.convert(transcription)

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


def _audio_duration(path: str) -> Optional[float]:
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
            capture_output=True, text=True, timeout=30, check=True,
        )
        return round(float(out.stdout.strip()), 2)
    except (subprocess.SubprocessError, ValueError):
        return None


def _transcribe_fun_asr_nano(model, path: str, selected_model: str) -> dict:
    # Fun-ASR-Nano takes no free-text prompt or language code the way Whisper does;
    # it detects Chinese, English and Japanese on its own.
    results = model.generate(input=path, batch_size_s=120)
    transcription = collapse_repeats("".join(r.get("text", "") for r in results).strip())
    language = "zh" if _CJK_RE.search(transcription) else None
    if language == "zh":
        transcription = _s2twp.convert(transcription)

    logger.info(f"Transcription complete: {len(transcription)} chars, model={selected_model}")
    return {
        "text": transcription,
        "language": language,
        "duration": _audio_duration(path),
        "language_probability": None,
        "model_used": selected_model,
    }


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