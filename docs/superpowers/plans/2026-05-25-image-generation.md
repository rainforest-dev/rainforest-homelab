# Image Generation Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy a self-hosted Flux image generation service behind a single OpenAI-compatible `/v1/images/generations` endpoint shared by Hermes Agent, Open WebUI, n8n, and Flowise.

**Architecture:** ComfyUI runs natively on Mac Mini (MPS/Metal) at port 8188. A thin FastAPI Docker container (`comfyui-adapter`) wraps ComfyUI's queue/history API into the OpenAI image API. All consumers point to the adapter; Cloudflare Tunnel exposes both the adapter API and the ComfyUI web UI externally.

**Tech Stack:** Python 3.11, FastAPI, httpx, UV, Docker, Terraform (kreuzwerker/docker provider), ComfyUI, ComfyUI-GGUF extension, Flux.1-schnell GGUF Q6_K

---

## File Map

**Create:**
- `modules/comfyui-adapter/main.tf` — Docker image build + container resource
- `modules/comfyui-adapter/variables.tf` — comfyui_host, api_key, port, model names
- `modules/comfyui-adapter/outputs.tf` — service_url, api_endpoint
- `modules/comfyui-adapter/Dockerfile` — two-stage UV build (mirrors Whisper)
- `modules/comfyui-adapter/app/pyproject.toml` — fastapi, httpx, uvicorn deps
- `modules/comfyui-adapter/app/main.py` — FastAPI app, /v1/images/generations endpoint
- `modules/comfyui-adapter/app/workflow.json` — Flux.1-schnell GGUF ComfyUI workflow template
- `modules/comfyui-adapter/app/tests/test_main.py` — unit tests with mocked ComfyUI

**Modify:**
- `variables.tf` — add enable_comfyui_adapter, comfyui_host, image_gen_api_key
- `locals.tf` — add comfyui and image-gen service entries
- `main.tf` — add module "comfyui_adapter" block; update module "open-webui" with image gen vars
- `modules/open-webui/variables.tf` — add image_gen_url, image_gen_api_key
- `modules/open-webui/main.tf` — add image gen env vars to Helm extraEnvVars

---

## Task 1: ComfyUI Native Install + Flux Model Setup

> This task is manual setup on the Mac Mini — not automated by Terraform. ComfyUI cannot run in Docker on macOS (no Metal/MPS access from Linux containers).

**Files:** None in repo — this is a runbook.

- [ ] **Step 1: Install ComfyUI natively**

```bash
# On Mac Mini, in your preferred location (e.g. ~/Applications/)
git clone https://github.com/comfyanonymous/ComfyUI ~/Applications/ComfyUI
cd ~/Applications/ComfyUI

# Create virtual environment and install PyTorch with MPS support
python3 -m venv .venv
source .venv/bin/activate
pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cpu
pip install -r requirements.txt
```

- [ ] **Step 2: Install ComfyUI-GGUF extension (required for GGUF model loading)**

```bash
cd ~/Applications/ComfyUI/custom_nodes
git clone https://github.com/city96/ComfyUI-GGUF
cd ComfyUI-GGUF
pip install -r requirements.txt
```

- [ ] **Step 3: Download Flux model files**

```bash
pip install huggingface_hub

# UNET model — Flux.1-schnell GGUF Q6_K (~7GB, fits in 16GB unified memory)
huggingface-cli download city96/FLUX.1-schnell-gguf \
  flux1-schnell-Q6_K.gguf \
  --local-dir ~/Applications/ComfyUI/models/unet/

# Text encoder 1 — T5-XXL (required by Flux)
huggingface-cli download comfyanonymous/flux_text_encoders \
  t5xxl_fp16.safetensors \
  --local-dir ~/Applications/ComfyUI/models/clip/

# Text encoder 2 — CLIP-L (required by Flux)
huggingface-cli download comfyanonymous/flux_text_encoders \
  clip_l.safetensors \
  --local-dir ~/Applications/ComfyUI/models/clip/

# VAE — Flux AE
huggingface-cli download black-forest-labs/FLUX.1-schnell \
  ae.safetensors \
  --local-dir ~/Applications/ComfyUI/models/vae/
```

- [ ] **Step 4: Start ComfyUI and verify**

```bash
cd ~/Applications/ComfyUI
source .venv/bin/activate
python main.py --listen 0.0.0.0 --port 8188
```

Open `http://localhost:8188` in a browser. You should see the ComfyUI node editor.

- [ ] **Step 5: Verify ComfyUI API is responding**

```bash
curl http://localhost:8188/system_stats
# Expected: {"system": {"os": "...", ...}, "devices": [...]}
```

- [ ] **Step 6: Set up ComfyUI as a launchd service (auto-start on login)**

```bash
cat > ~/Library/LaunchAgents/com.comfyui.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.comfyui</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/rainforest/Applications/ComfyUI/.venv/bin/python</string>
    <string>main.py</string>
    <string>--listen</string>
    <string>0.0.0.0</string>
    <string>--port</string>
    <string>8188</string>
  </array>
  <key>WorkingDirectory</key>
  <string>/Users/rainforest/Applications/ComfyUI</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/comfyui.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/comfyui.err</string>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.comfyui.plist
# Verify it started:
curl http://localhost:8188/system_stats
```

---

## Task 2: FastAPI Adapter App — Tests First

**Files:**
- Create: `modules/comfyui-adapter/app/pyproject.toml`
- Create: `modules/comfyui-adapter/app/workflow.json`
- Create: `modules/comfyui-adapter/app/tests/test_main.py`
- Create: `modules/comfyui-adapter/app/main.py`

- [ ] **Step 1: Create pyproject.toml**

```bash
mkdir -p modules/comfyui-adapter/app/tests
touch modules/comfyui-adapter/app/tests/__init__.py
```

Create `modules/comfyui-adapter/app/pyproject.toml`:

```toml
[project]
name = "comfyui-adapter"
version = "0.1.0"
description = "OpenAI-compatible image generation API adapter for ComfyUI"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.34.0",
    "httpx>=0.27.0",
    "python-multipart>=0.0.20",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.24.0",
    "respx>=0.21.0",
]
```

- [ ] **Step 2: Create workflow.json template**

Create `modules/comfyui-adapter/app/workflow.json`:

```json
{
  "1": {
    "class_type": "UnetLoaderGGUF",
    "inputs": {
      "unet_name": "flux1-schnell-Q6_K.gguf"
    }
  },
  "2": {
    "class_type": "DualCLIPLoader",
    "inputs": {
      "clip_name1": "t5xxl_fp16.safetensors",
      "clip_name2": "clip_l.safetensors",
      "type": "flux"
    }
  },
  "3": {
    "class_type": "VAELoader",
    "inputs": {
      "vae_name": "ae.safetensors"
    }
  },
  "4": {
    "class_type": "CLIPTextEncode",
    "inputs": {
      "text": "",
      "clip": ["2", 0]
    }
  },
  "5": {
    "class_type": "EmptySD3LatentImage",
    "inputs": {
      "width": 1024,
      "height": 1024,
      "batch_size": 1
    }
  },
  "6": {
    "class_type": "ModelSamplingFlux",
    "inputs": {
      "model": ["1", 0],
      "max_shift": 1.15,
      "base_shift": 0.5,
      "width": 1024,
      "height": 1024
    }
  },
  "7": {
    "class_type": "KSampler",
    "inputs": {
      "model": ["6", 0],
      "positive": ["4", 0],
      "negative": ["8", 0],
      "latent_image": ["5", 0],
      "seed": 0,
      "steps": 4,
      "cfg": 1.0,
      "sampler_name": "euler",
      "scheduler": "simple",
      "denoise": 1.0
    }
  },
  "8": {
    "class_type": "CLIPTextEncode",
    "inputs": {
      "text": "",
      "clip": ["2", 0]
    }
  },
  "9": {
    "class_type": "VAEDecode",
    "inputs": {
      "samples": ["7", 0],
      "vae": ["3", 0]
    }
  },
  "10": {
    "class_type": "SaveImage",
    "inputs": {
      "images": ["9", 0],
      "filename_prefix": "adapter"
    }
  }
}
```

- [ ] **Step 3: Write failing tests**

Create `modules/comfyui-adapter/app/tests/test_main.py`:

```python
import base64
import json
import pytest
import respx
import httpx
from httpx import AsyncClient, Response
from unittest.mock import patch

# ── helpers ──────────────────────────────────────────────────────────────────

FAKE_B64 = base64.b64encode(b"fake-png-bytes").decode()
FAKE_PROMPT_ID = "abc-123"
COMFYUI_URL = "http://localhost:8188"


def make_history_response(prompt_id: str) -> dict:
    return {
        prompt_id: {
            "outputs": {
                "10": {
                    "images": [
                        {"filename": "adapter_00001_.png", "subfolder": "", "type": "output"}
                    ]
                }
            }
        }
    }


# ── tests ────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_health():
    from main import app
    async with AsyncClient(app=app, base_url="http://test") as client:
        r = await client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "healthy"


@pytest.mark.asyncio
async def test_generate_image_returns_base64():
    from main import app

    with respx.mock:
        # Mock ComfyUI /prompt endpoint
        respx.post(f"{COMFYUI_URL}/prompt").mock(
            return_value=Response(200, json={"prompt_id": FAKE_PROMPT_ID})
        )
        # First call: not done yet; second call: done
        history_calls = [
            Response(200, json={}),
            Response(200, json=make_history_response(FAKE_PROMPT_ID)),
        ]
        respx.get(f"{COMFYUI_URL}/history/{FAKE_PROMPT_ID}").mock(
            side_effect=history_calls
        )
        # Mock /view for image bytes
        respx.get(f"{COMFYUI_URL}/view").mock(
            return_value=Response(200, content=b"fake-png-bytes")
        )

        async with AsyncClient(app=app, base_url="http://test") as client:
            r = await client.post(
                "/v1/images/generations",
                json={"prompt": "a red fox", "n": 1, "size": "1024x1024"},
            )

    assert r.status_code == 200
    body = r.json()
    assert "data" in body
    assert len(body["data"]) == 1
    assert body["data"][0]["b64_json"] == FAKE_B64


@pytest.mark.asyncio
async def test_generate_image_injects_prompt_into_workflow():
    from main import app
    import main as app_module

    captured_workflow = {}

    async def fake_post(url, **kwargs):
        if "/prompt" in str(url):
            captured_workflow.update(json.loads(kwargs.get("content", "{}")))
            return Response(200, json={"prompt_id": FAKE_PROMPT_ID})
        return Response(404)

    with respx.mock:
        respx.post(f"{COMFYUI_URL}/prompt").mock(side_effect=fake_post)
        respx.get(f"{COMFYUI_URL}/history/{FAKE_PROMPT_ID}").mock(
            return_value=Response(200, json=make_history_response(FAKE_PROMPT_ID))
        )
        respx.get(f"{COMFYUI_URL}/view").mock(
            return_value=Response(200, content=b"fake-png-bytes")
        )

        async with AsyncClient(app=app, base_url="http://test") as client:
            await client.post(
                "/v1/images/generations",
                json={"prompt": "a red fox", "n": 1, "size": "512x512"},
            )

    workflow = captured_workflow.get("prompt", {})
    assert workflow["4"]["inputs"]["text"] == "a red fox"
    assert workflow["5"]["inputs"]["width"] == 512
    assert workflow["5"]["inputs"]["height"] == 512
    assert workflow["6"]["inputs"]["width"] == 512
    assert workflow["6"]["inputs"]["height"] == 512


@pytest.mark.asyncio
async def test_api_key_required_when_configured(monkeypatch):
    monkeypatch.setenv("API_KEY", "secret-key")
    # Re-import to pick up env change
    import importlib
    import main
    importlib.reload(main)

    async with AsyncClient(app=main.app, base_url="http://test") as client:
        r = await client.post(
            "/v1/images/generations",
            json={"prompt": "test"},
        )
    assert r.status_code == 401


@pytest.mark.asyncio
async def test_api_key_accepted_when_correct(monkeypatch):
    monkeypatch.setenv("API_KEY", "secret-key")
    import importlib
    import main
    importlib.reload(main)

    with respx.mock:
        respx.post(f"{COMFYUI_URL}/prompt").mock(
            return_value=Response(200, json={"prompt_id": FAKE_PROMPT_ID})
        )
        respx.get(f"{COMFYUI_URL}/history/{FAKE_PROMPT_ID}").mock(
            return_value=Response(200, json=make_history_response(FAKE_PROMPT_ID))
        )
        respx.get(f"{COMFYUI_URL}/view").mock(
            return_value=Response(200, content=b"fake-png-bytes")
        )

        async with AsyncClient(app=main.app, base_url="http://test") as client:
            r = await client.post(
                "/v1/images/generations",
                json={"prompt": "test"},
                headers={"Authorization": "Bearer secret-key"},
            )
    assert r.status_code == 200
```

- [ ] **Step 4: Run tests — expect ImportError (main.py doesn't exist yet)**

```bash
cd modules/comfyui-adapter/app
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
pytest tests/ -v
# Expected: ModuleNotFoundError: No module named 'main'
```

- [ ] **Step 5: Create main.py**

Create `modules/comfyui-adapter/app/main.py`:

```python
import asyncio
import base64
import json
import logging
import os
import random
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
_base_workflow: dict = {}

security = HTTPBearer(auto_error=False)

app = FastAPI(
    title="ComfyUI Adapter",
    description="OpenAI-compatible image generation API backed by ComfyUI",
    version="0.1.0",
)


def _load_workflow() -> dict:
    with open(WORKFLOW_PATH) as f:
        return json.load(f)


@app.on_event("startup")
async def startup():
    global _base_workflow
    _base_workflow = _load_workflow()
    logger.info(f"Loaded workflow template from {WORKFLOW_PATH}")
    logger.info(f"ComfyUI backend: {COMFYUI_HOST}")
    logger.info(f"API key auth: {'enabled' if API_KEY else 'disabled'}")


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
    deadline = asyncio.get_event_loop().time() + TIMEOUT_SECONDS
    async with httpx.AsyncClient() as client:
        while asyncio.get_event_loop().time() < deadline:
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
    except TimeoutError as e:
        raise HTTPException(status_code=504, detail=str(e))
    except httpx.HTTPError as e:
        raise HTTPException(status_code=502, detail=f"ComfyUI error: {e}")

    images = []
    for node_output in outputs.values():
        for img_meta in node_output.get("images", []):
            b64 = await _fetch_image_b64(img_meta)
            images.append({"b64_json": b64})
            if len(images) >= req.n:
                break
        if len(images) >= req.n:
            break

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
```

- [ ] **Step 6: Run tests — all should pass**

```bash
cd modules/comfyui-adapter/app
pytest tests/ -v
# Expected:
# test_health PASSED
# test_generate_image_returns_base64 PASSED
# test_generate_image_injects_prompt_into_workflow PASSED
# test_api_key_required_when_configured PASSED
# test_api_key_accepted_when_correct PASSED
```

- [ ] **Step 7: Commit**

```bash
git add modules/comfyui-adapter/app/
git commit -m "feat: add comfyui-adapter FastAPI app with OpenAI-compatible image endpoint"
```

---

## Task 3: Dockerfile

**Files:**
- Create: `modules/comfyui-adapter/Dockerfile`

- [ ] **Step 1: Create Dockerfile (mirrors Whisper pattern)**

Create `modules/comfyui-adapter/Dockerfile`:

```dockerfile
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim AS builder

WORKDIR /app
COPY app/pyproject.toml ./
RUN uv sync --frozen --no-dev

FROM python:3.11-slim

WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY app/main.py app/workflow.json ./

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 7860

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:7860/health')"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]
```

- [ ] **Step 2: Build image locally to verify it works**

```bash
cd modules/comfyui-adapter
docker build -t homelab/comfyui-adapter:test .
# Expected: Successfully built <image-id>
```

- [ ] **Step 3: Smoke test the built image against a running ComfyUI**

```bash
# ComfyUI must be running at localhost:8188 (from Task 1)
docker run --rm -p 7860:7860 \
  -e COMFYUI_HOST=http://host.docker.internal:8188 \
  homelab/comfyui-adapter:test &

sleep 3
curl http://localhost:7860/health
# Expected: {"status":"healthy","comfyui_host":"http://host.docker.internal:8188"}

# Clean up
docker stop $(docker ps -q --filter ancestor=homelab/comfyui-adapter:test)
```

- [ ] **Step 4: Commit**

```bash
git add modules/comfyui-adapter/Dockerfile
git commit -m "feat: add comfyui-adapter Dockerfile (two-stage UV build)"
```

---

## Task 4: Terraform Module

**Files:**
- Create: `modules/comfyui-adapter/variables.tf`
- Create: `modules/comfyui-adapter/outputs.tf`
- Create: `modules/comfyui-adapter/main.tf`

- [ ] **Step 1: Create variables.tf**

Create `modules/comfyui-adapter/variables.tf`:

```hcl
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "comfyui_host" {
  description = "ComfyUI backend URL. Use host.docker.internal for Mac Mini, or PC LAN IP."
  type        = string
  default     = "http://host.docker.internal:8188"
}

variable "api_key" {
  description = "Bearer token required on Authorization header. Empty = no auth."
  type        = string
  default     = ""
  sensitive   = true
}

variable "external_port" {
  description = "Host port the adapter listens on"
  type        = number
  default     = 7860
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "domain_suffix" {
  description = "Domain suffix for external access URL output"
  type        = string
  default     = ""
}
```

- [ ] **Step 2: Create outputs.tf**

Create `modules/comfyui-adapter/outputs.tf`:

```hcl
output "service_url" {
  description = "Internal URL accessible from Docker host"
  value       = "http://host.docker.internal:${var.external_port}"
}

output "tunnel_service_url" {
  description = "Internal URL for Cloudflare Tunnel routing"
  value       = "http://host.docker.internal:${var.external_port}"
}

output "external_url" {
  description = "External HTTPS URL via Cloudflare Tunnel"
  value       = var.domain_suffix != "" ? "https://image-gen.${var.domain_suffix}" : ""
}

output "api_endpoint" {
  description = "OpenAI-compatible image generation endpoint"
  value       = "http://host.docker.internal:${var.external_port}/v1/images/generations"
}

output "container_name" {
  description = "Docker container name"
  value       = docker_container.comfyui_adapter.name
}
```

- [ ] **Step 3: Create main.tf**

Create `modules/comfyui-adapter/main.tf`:

```hcl
resource "docker_image" "comfyui_adapter" {
  name = "${var.project_name}/comfyui-adapter:${var.image_tag}"

  build {
    context    = path.module
    dockerfile = "Dockerfile"
    tag        = ["${var.project_name}/comfyui-adapter:${var.image_tag}"]
    label = {
      project = var.project_name
      service = "comfyui-adapter"
    }
  }

  triggers = {
    dockerfile_hash  = filemd5("${path.module}/Dockerfile")
    main_py_hash     = filemd5("${path.module}/app/main.py")
    workflow_hash    = filemd5("${path.module}/app/workflow.json")
    pyproject_hash   = filemd5("${path.module}/app/pyproject.toml")
  }
}

resource "docker_container" "comfyui_adapter" {
  image   = docker_image.comfyui_adapter.name
  name    = "${var.project_name}-comfyui-adapter"
  restart = "unless-stopped"

  ports {
    internal = 7860
    external = var.external_port
  }

  env = compact([
    "COMFYUI_HOST=${var.comfyui_host}",
    var.api_key != "" ? "API_KEY=${var.api_key}" : "",
  ])

  labels {
    label = "project"
    value = var.project_name
  }

  labels {
    label = "service"
    value = "comfyui-adapter"
  }

  labels {
    label = "environment"
    value = var.environment
  }

  depends_on = [docker_image.comfyui_adapter]
}
```

- [ ] **Step 4: Validate Terraform module syntax**

```bash
cd modules/comfyui-adapter
terraform init
# Expected: no error (or "Terraform initialized in an empty directory" — that's fine)
```

Run from repo root:

```bash
terraform validate
# Expected: Success! The configuration is valid.
```

- [ ] **Step 5: Commit**

```bash
git add modules/comfyui-adapter/variables.tf modules/comfyui-adapter/outputs.tf modules/comfyui-adapter/main.tf
git commit -m "feat: add comfyui-adapter Terraform module"
```

---

## Task 5: Root Terraform Wiring

**Files:**
- Modify: `variables.tf` (root)
- Modify: `locals.tf`
- Modify: `main.tf` (root)

- [ ] **Step 1: Add variables to root variables.tf**

In `variables.tf`, after the existing `enable_homeassistant` variable block, add:

```hcl
variable "enable_comfyui_adapter" {
  description = "Enable the ComfyUI OpenAI-compatible image generation adapter"
  type        = bool
  default     = false
}

variable "comfyui_host" {
  description = "ComfyUI backend URL. Default: Mac Mini native install. Override with PC LAN IP for GPU mode."
  type        = string
  default     = "http://host.docker.internal:8188"
}

variable "image_gen_api_key" {
  description = "API key for the image-gen adapter. Empty = no auth (internal use only)."
  type        = string
  default     = ""
  sensitive   = true
}
```

- [ ] **Step 2: Add service entries to locals.tf**

In `locals.tf`, inside the `services = merge(` block, add after the `whisper` entry (before the closing `)`):

```hcl
    {
      comfyui = {
        hostname    = "comfyui"
        service_url = "http://host.docker.internal:8188"
        enable_auth = true
        type        = "docker"
      }
    },

    var.enable_comfyui_adapter ? {
      "image-gen" = {
        hostname    = "image-gen"
        service_url = "http://host.docker.internal:7860"
        enable_auth = false
        type        = "docker"
      }
    } : {},
```

- [ ] **Step 3: Add module call to main.tf**

In `main.tf`, after the `module "whisper"` block, add:

```hcl
module "comfyui_adapter" {
  count  = var.enable_comfyui_adapter ? 1 : 0
  source = "./modules/comfyui-adapter"

  project_name  = var.project_name
  environment   = var.environment
  comfyui_host  = var.comfyui_host
  api_key       = var.image_gen_api_key
  external_port = 7860
  image_tag     = "latest"
  domain_suffix = var.domain_suffix
}
```

- [ ] **Step 4: Validate**

```bash
terraform validate
# Expected: Success! The configuration is valid.

terraform plan -var="enable_comfyui_adapter=true"
# Expected: Plan shows docker_image + docker_container being created, plus 2 new Cloudflare tunnel entries
```

- [ ] **Step 5: Commit**

```bash
git add variables.tf locals.tf main.tf
git commit -m "feat: wire comfyui-adapter into root Terraform and Cloudflare Tunnel"
```

---

## Task 6: Open WebUI Image Generation Wiring

**Files:**
- Modify: `modules/open-webui/variables.tf`
- Modify: `modules/open-webui/main.tf`
- Modify: `main.tf` (root) — update module "open-webui" block

- [ ] **Step 1: Add variables to modules/open-webui/variables.tf**

At the end of `modules/open-webui/variables.tf`, add:

```hcl
variable "image_gen_url" {
  description = "Base URL for OpenAI-compatible image generation API (e.g. https://image-gen.rainforest.tools)"
  type        = string
  default     = ""
}

variable "image_gen_api_key" {
  description = "API key for image generation service"
  type        = string
  default     = ""
  sensitive   = true
}
```

- [ ] **Step 2: Add image gen env vars to Helm extraEnvVars in modules/open-webui/main.tf**

In `modules/open-webui/main.tf`, find the `extraEnvVars = concat(` block (around line 150) and extend it. Replace the closing `[]` of the last `whisper_stt_url` conditional with:

```hcl
      extraEnvVars = concat(
        var.ollama_base_url != "" ? [
          {
            name  = "OLLAMA_BASE_URL"
            value = var.ollama_base_url
          }
        ] : [],
        var.database_url != "" ? [
          {
            name  = "DATABASE_URL"
            value = var.database_url
          }
        ] : [],
        var.whisper_stt_url != "" ? [
          {
            name  = "AUDIO_STT_ENGINE"
            value = "openai"
          },
          {
            name  = "AUDIO_STT_OPENAI_API_BASE_URL"
            value = "${var.whisper_stt_url}/v1"
          }
        ] : [],
        var.image_gen_url != "" ? [
          {
            name  = "ENABLE_IMAGE_GENERATION"
            value = "true"
          },
          {
            name  = "IMAGE_GENERATION_ENGINE"
            value = "openai"
          },
          {
            name  = "IMAGES_OPENAI_API_BASE_URL"
            value = "${var.image_gen_url}/v1"
          },
          {
            name  = "IMAGES_OPENAI_API_KEY"
            value = var.image_gen_api_key != "" ? var.image_gen_api_key : "homelab-internal"
          }
        ] : []
      )
```

- [ ] **Step 3: Pass image gen vars in root main.tf module "open-webui" block**

In `main.tf`, find `module "open-webui"` (line 141) and add inside the block, after `whisper_stt_url`:

```hcl
  # Image generation integration
  image_gen_url     = var.enable_comfyui_adapter ? "https://image-gen.${var.domain_suffix}" : ""
  image_gen_api_key = var.image_gen_api_key
```

- [ ] **Step 4: Validate**

```bash
terraform validate
# Expected: Success! The configuration is valid.

terraform plan -var="enable_comfyui_adapter=true"
# Expected: helm_release.open-webui will be updated in-place with new extraEnvVars
```

- [ ] **Step 5: Commit**

```bash
git add modules/open-webui/variables.tf modules/open-webui/main.tf main.tf
git commit -m "feat: wire image generation into Open WebUI Helm values"
```

---

## Task 7: Hermes Agent Plugin

> These files live inside your Hermes Agent installation directory, not in this repo. Find your Hermes Agent install path with `hermes --version` or check `~/.hermes/`.

**Files (outside repo):**
- Create: `<hermes-install>/plugins/image_gen/comfyui-compat/plugin.yaml`
- Create: `<hermes-install>/plugins/image_gen/comfyui-compat/__init__.py`

- [ ] **Step 1: Find Hermes Agent plugins directory**

```bash
# Locate Hermes Agent installation
which hermes
hermes --version

# Plugins directory is typically:
ls ~/.hermes/plugins/image_gen/
# or
ls $(hermes --show-home)/plugins/image_gen/
```

- [ ] **Step 2: Create plugin directory**

```bash
mkdir -p $(hermes --show-home)/plugins/image_gen/comfyui-compat
```

- [ ] **Step 3: Create plugin.yaml**

Create `<hermes-home>/plugins/image_gen/comfyui-compat/plugin.yaml`:

```yaml
kind: backend
name: comfyui-compat
display_name: ComfyUI (self-hosted)
description: Self-hosted Flux image generation via ComfyUI adapter
version: "0.1.0"
```

- [ ] **Step 4: Create __init__.py**

Create `<hermes-home>/plugins/image_gen/comfyui-compat/__init__.py`:

```python
import httpx
from hermes.image_gen import ImageGenProvider, success_response, error_response, save_b64_image


def _ratio_to_size(aspect_ratio: str) -> str:
    mapping = {
        "1:1":  "1024x1024",
        "16:9": "1344x768",
        "9:16": "768x1344",
        "4:3":  "1152x864",
        "3:4":  "864x1152",
    }
    return mapping.get(aspect_ratio, "1024x1024")


class ComfyUICompatProvider(ImageGenProvider):
    name = "comfyui-compat"
    display_name = "ComfyUI (self-hosted)"

    def is_available(self) -> bool:
        return bool(self.config.get("base_url"))

    def list_models(self) -> list[str]:
        return ["flux-schnell"]

    def default_model(self) -> str:
        return "flux-schnell"

    def get_setup_schema(self) -> dict:
        return {
            "base_url": {
                "description": "Adapter base URL (e.g. https://image-gen.rainforest.tools/v1)",
                "required": True,
            },
            "api_key": {
                "description": "Bearer token (leave empty if adapter has no auth)",
                "required": False,
            },
        }

    def generate(self, prompt: str, aspect_ratio: str = "1:1", **kwargs):
        base_url = self.config.get("base_url", "").rstrip("/")
        api_key = self.config.get("api_key", "")
        size = _ratio_to_size(aspect_ratio)

        headers = {}
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"

        try:
            resp = httpx.post(
                f"{base_url}/images/generations",
                json={"prompt": prompt, "size": size, "n": 1},
                headers=headers,
                timeout=360,
            )
            resp.raise_for_status()
            b64 = resp.json()["data"][0]["b64_json"]
            path = save_b64_image(b64)
            return success_response(
                image=path,
                model="flux-schnell",
                prompt=prompt,
                aspect_ratio=aspect_ratio,
                provider=self.name,
            )
        except httpx.TimeoutException:
            return error_response(
                error="Image generation timed out (>6 min)",
                error_type="timeout",
                provider=self.name,
            )
        except Exception as e:
            return error_response(
                error=str(e),
                error_type="request_failed",
                provider=self.name,
            )


def register(ctx):
    ctx.register_provider(ComfyUICompatProvider)
```

- [ ] **Step 5: Configure Hermes to use the plugin**

Edit `~/.hermes/config.yaml` (or wherever your Hermes config lives):

```yaml
image_gen:
  provider: comfyui-compat
  comfyui_compat:
    base_url: https://image-gen.rainforest.tools/v1
    api_key: ""   # leave empty if image_gen_api_key is not set in terraform.tfvars
```

- [ ] **Step 6: Verify plugin loads**

```bash
hermes tools list | grep image
# Expected: image_generate   Generate an image from a text prompt  [comfyui-compat]
```

---

## Task 8: Deploy and End-to-End Test

- [ ] **Step 1: Set terraform.tfvars**

In `terraform.tfvars`, add:

```hcl
enable_comfyui_adapter = true
comfyui_host           = "http://host.docker.internal:8188"
# image_gen_api_key    = "your-secret"  # optional
```

- [ ] **Step 2: Apply Terraform**

```bash
terraform plan   # review: 1 docker_image, 1 docker_container, 2 cloudflare resources
terraform apply
# Expected: Apply complete! Resources: N added, M changed, 0 destroyed.
```

- [ ] **Step 3: Verify adapter container is healthy**

```bash
docker ps --filter name=homelab-comfyui-adapter
# Expected: STATUS = Up ... (healthy)

curl http://localhost:7860/health
# Expected: {"status":"healthy","comfyui_host":"http://host.docker.internal:8188"}
```

- [ ] **Step 4: Test image generation via adapter (ComfyUI must be running)**

```bash
curl -X POST http://localhost:7860/v1/images/generations \
  -H "Content-Type: application/json" \
  -d '{"prompt": "a red fox sitting in a snowy forest, photorealistic", "size": "1024x1024"}' \
  | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
img = base64.b64decode(data['data'][0]['b64_json'])
open('/tmp/test_output.png', 'wb').write(img)
print('Image saved to /tmp/test_output.png')
"
open /tmp/test_output.png
# Expected: a generated image opens in Preview
```

- [ ] **Step 5: Test via Cloudflare Tunnel (external URL)**

```bash
curl -X POST https://image-gen.rainforest.tools/v1/images/generations \
  -H "Content-Type: application/json" \
  -d '{"prompt": "a blue mountain lake at sunrise", "size": "1024x1024"}' \
  -o /tmp/tunnel_test.json

python3 -c "
import json, base64
data = json.load(open('/tmp/tunnel_test.json'))
img = base64.b64decode(data['data'][0]['b64_json'])
open('/tmp/tunnel_output.png', 'wb').write(img)
print('Tunnel test: OK')
"
```

- [ ] **Step 6: Verify Open WebUI image generation**

1. Open `https://open-webui.rainforest.tools`
2. Click the image icon (🖼) in the chat input or go to Admin → Settings → Images
3. The "Image Generation Engine" should show "OpenAI" and the endpoint should be pre-configured
4. In a chat, type: `/image a cyberpunk city at night`
5. Expected: generated image appears inline in the chat

- [ ] **Step 7: Verify Hermes Agent generates an image**

```bash
hermes "generate an image of a tabby cat sitting on a windowsill"
# Expected: Hermes calls image_generate tool, saves image, returns file path
```

- [ ] **Step 8: Final commit**

```bash
git add terraform.tfvars  # only if you want to commit the tfvars change
git commit -m "feat: enable comfyui-adapter in terraform.tfvars"
```

---

## PC GPU Mode (When RTX 5070 Is Available)

To switch image generation to the PC with RTX 5070:

1. Install ComfyUI natively on the PC (same steps as Task 1, Windows/Linux)
2. Download `flux1-schnell.safetensors` (FP8) instead of GGUF:
   ```bash
   huggingface-cli download black-forest-labs/FLUX.1-schnell flux1-schnell.safetensors
   ```
3. Update the workflow.json to use `UNETLoader` instead of `UnetLoaderGGUF` and `flux1-schnell.safetensors`
4. In `terraform.tfvars`, set:
   ```hcl
   comfyui_host = "http://192.168.1.<pc-ip>:8188"
   ```
5. `terraform apply` — adapter reconfigures to point at PC, nothing else changes

---

## Troubleshooting

**Adapter returns 502:** ComfyUI is not running or not reachable. Check `curl http://localhost:8188/system_stats`.

**Generation hangs / 504:** Model files are missing or not loaded. Check `docker logs homelab-comfyui-adapter` and ComfyUI console for errors. Ensure all four model files are downloaded (Task 1, Step 3).

**"UnetLoaderGGUF not found":** ComfyUI-GGUF extension is not installed or not loaded. Restart ComfyUI after installing the extension.

**Open WebUI image icon missing:** `ENABLE_IMAGE_GENERATION=true` may not have propagated. Run `terraform apply` again and restart the Open WebUI pod.
