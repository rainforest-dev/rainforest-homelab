"""ComfyUI-compatible image generation backend.

Routes requests through the comfyui-adapter FastAPI service (port 7860),
which translates OpenAI-style ``/v1/images/generations`` calls into ComfyUI
workflow submissions.

Configuration via environment variables::

    COMFYUI_ADAPTER_URL   Base URL of the adapter, e.g.
                          "http://localhost:7860/v1" (local)
                          or "https://image-gen.rainforest.tools/v1" (tunnel)
    COMFYUI_ADAPTER_KEY   Optional Bearer token (leave unset if adapter has
                          no auth configured).
"""

from __future__ import annotations

import logging
import os

import httpx
from agent.image_gen_provider import (
    ImageGenProvider,
    error_response,
    save_b64_image,
    success_response,
)

logger = logging.getLogger(__name__)

# Aspect-ratio → pixel size mapping.
# Hermes calls generate() with "landscape" / "square" / "portrait".
_ASPECT_TO_SIZE: dict[str, str] = {
    "landscape": "1344x768",
    "square":    "1024x1024",
    "portrait":  "768x1344",
}


class ComfyUICompatProvider(ImageGenProvider):
    name = "comfyui-compat"
    display_name = "ComfyUI (self-hosted)"

    def is_available(self) -> bool:
        return bool(os.environ.get("COMFYUI_ADAPTER_URL"))

    def list_models(self) -> list[dict]:
        return [{"id": "flux-schnell", "display": "Flux Schnell (GGUF)", "speed": "~15s"}]

    def default_model(self) -> str:
        return "flux-schnell"

    def get_setup_schema(self) -> dict:
        return {
            "name": self.display_name,
            "badge": "self-hosted",
            "tag": "Flux Schnell via local ComfyUI — Metal/MPS accelerated",
            "env_vars": [
                {
                    "key": "COMFYUI_ADAPTER_URL",
                    "prompt": "Adapter base URL",
                    "hint": "e.g. http://localhost:7860/v1",
                },
                {
                    "key": "COMFYUI_ADAPTER_KEY",
                    "prompt": "Bearer token (leave blank if adapter has no auth)",
                    "optional": True,
                },
            ],
        }

    def generate(self, prompt: str, aspect_ratio: str = "landscape", **kwargs):
        base_url = (os.environ.get("COMFYUI_ADAPTER_URL") or "").rstrip("/")
        api_key = os.environ.get("COMFYUI_ADAPTER_KEY", "")
        size = _ASPECT_TO_SIZE.get(aspect_ratio, "1024x1024")

        headers: dict[str, str] = {}
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"

        logger.info("ComfyUI generate: prompt=%r size=%s", prompt, size)
        try:
            resp = httpx.post(
                f"{base_url}/images/generations",
                json={"prompt": prompt, "size": size, "n": 1},
                headers=headers,
                timeout=360.0,
            )
            resp.raise_for_status()
            b64 = resp.json()["data"][0]["b64_json"]
            path = save_b64_image(b64)
            return success_response(
                image=str(path),
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
        except Exception as exc:
            return error_response(
                error=str(exc),
                error_type="request_failed",
                provider=self.name,
            )


def register(ctx) -> None:
    """Plugin entry point — wire ComfyUICompatProvider into the registry."""
    ctx.register_image_gen_provider(ComfyUICompatProvider())
