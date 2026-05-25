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
