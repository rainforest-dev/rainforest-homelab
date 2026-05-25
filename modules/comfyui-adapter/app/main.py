import asyncio
import base64
import json
import logging
import os
import random
from contextlib import asynccontextmanager
from pathlib import Path

import httpx
from fastapi import FastAPI, HTTPException, Security
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

COMFYUI_HOST = os.getenv("COMFYUI_HOST", "http://host.docker.internal:8188")
API_KEY = os.getenv("API_KEY", "")
POLL_INTERVAL = float(os.getenv("POLL_INTERVAL", "1.0"))
TIMEOUT_SECONDS = int(os.getenv("TIMEOUT_SECONDS", "300"))

WORKFLOW_PATH = Path(__file__).parent / "workflow.json"


def _load_workflow() -> dict:
    with open(WORKFLOW_PATH) as f:
        return json.load(f)


# Load workflow at import time so it's available without lifespan startup
_base_workflow: dict = _load_workflow()

security = HTTPBearer(auto_error=False)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"Loaded workflow template from {WORKFLOW_PATH}")
    logger.info(f"ComfyUI backend: {COMFYUI_HOST}")
    logger.info(f"API key auth: {'enabled' if API_KEY else 'disabled'}")
    yield


app = FastAPI(
    title="ComfyUI Adapter",
    description="OpenAI-compatible image generation API backed by ComfyUI",
    version="0.1.0",
    lifespan=lifespan,
)


def _check_api_key(credentials: HTTPAuthorizationCredentials | None) -> None:
    if not API_KEY:
        return
    if credentials is None or credentials.credentials != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")


def _size_to_dimensions(size: str) -> tuple[int, int]:
    try:
        w, h = size.split("x")
        return int(w), int(h)
    except (ValueError, AttributeError):
        return 1024, 1024


def _build_workflow(prompt: str, width: int, height: int) -> dict:
    wf = json.loads(json.dumps(_base_workflow))
    wf["4"]["inputs"]["text"] = prompt
    wf["5"]["inputs"]["width"] = width
    wf["5"]["inputs"]["height"] = height
    wf["6"]["inputs"]["width"] = width
    wf["6"]["inputs"]["height"] = height
    wf["7"]["inputs"]["seed"] = random.randint(0, 2**32 - 1)
    return wf


async def _queue_prompt(workflow: dict) -> str:
    async with httpx.AsyncClient() as client:
        r = await client.post(
            f"{COMFYUI_HOST}/prompt",
            content=json.dumps({"prompt": workflow}),
            headers={"Content-Type": "application/json"},
            timeout=30,
        )
        r.raise_for_status()
        return r.json()["prompt_id"]


async def _poll_until_done(prompt_id: str) -> dict:
    deadline = asyncio.get_running_loop().time() + TIMEOUT_SECONDS
    async with httpx.AsyncClient() as client:
        while asyncio.get_running_loop().time() < deadline:
            r = await client.get(f"{COMFYUI_HOST}/history/{prompt_id}", timeout=10)
            data = r.json()
            if prompt_id in data:
                return data[prompt_id]["outputs"]
            await asyncio.sleep(POLL_INTERVAL)
    raise TimeoutError(f"Image generation timed out after {TIMEOUT_SECONDS}s")


async def _fetch_image_b64(image_meta: dict) -> str:
    async with httpx.AsyncClient() as client:
        r = await client.get(
            f"{COMFYUI_HOST}/view",
            params={
                "filename": image_meta["filename"],
                "subfolder": image_meta["subfolder"],
                "type": image_meta["type"],
            },
            timeout=30,
        )
        r.raise_for_status()
        return base64.b64encode(r.content).decode()


class ImageGenRequest(BaseModel):
    prompt: str
    n: int = 1
    size: str = "1024x1024"


@app.post("/v1/images/generations")
async def generate_image(
    req: ImageGenRequest,
    credentials: HTTPAuthorizationCredentials | None = Security(security),
):
    _check_api_key(credentials)

    width, height = _size_to_dimensions(req.size)
    workflow = _build_workflow(req.prompt, width, height)

    logger.info(f"Queueing generation: prompt={req.prompt!r} size={req.size}")
    try:
        prompt_id = await _queue_prompt(workflow)
        outputs = await _poll_until_done(prompt_id)

        images = []
        for node_output in outputs.values():
            for img_meta in node_output.get("images", []):
                b64 = await _fetch_image_b64(img_meta)
                images.append({"b64_json": b64})
                if len(images) >= req.n:
                    break
            if len(images) >= req.n:
                break
    except TimeoutError as e:
        raise HTTPException(status_code=504, detail=str(e))
    except httpx.HTTPError as e:
        raise HTTPException(status_code=502, detail=f"ComfyUI error: {e}")

    if not images:
        raise HTTPException(status_code=500, detail="No images in ComfyUI output")

    logger.info(f"Generation complete: {len(images)} image(s) for prompt_id={prompt_id}")
    return {"data": images}


@app.get("/v1/models")
async def list_models():
    return {
        "data": [
            {"id": "flux-schnell", "object": "model", "owned_by": "homelab"}
        ]
    }


@app.get("/health")
async def health():
    return {"status": "healthy", "comfyui_host": COMFYUI_HOST}
