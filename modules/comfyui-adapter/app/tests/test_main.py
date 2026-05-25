import base64
import json
import pytest
import respx
import httpx
from httpx import AsyncClient, ASGITransport, Response
from unittest.mock import patch

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


@pytest.mark.asyncio
async def test_health():
    from main import app
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        r = await client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "healthy"


@pytest.mark.asyncio
async def test_generate_image_returns_base64():
    from main import app

    with respx.mock:
        respx.post(f"{COMFYUI_URL}/prompt").mock(
            return_value=Response(200, json={"prompt_id": FAKE_PROMPT_ID})
        )
        history_calls = [
            Response(200, json={}),
            Response(200, json=make_history_response(FAKE_PROMPT_ID)),
        ]
        respx.get(f"{COMFYUI_URL}/history/{FAKE_PROMPT_ID}").mock(
            side_effect=history_calls
        )
        respx.get(f"{COMFYUI_URL}/view").mock(
            return_value=Response(200, content=b"fake-png-bytes")
        )

        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
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

    captured = {}

    async def fake_post(request):
        body = json.loads(request.content)
        captured["workflow"] = body.get("prompt", {})
        return Response(200, json={"prompt_id": FAKE_PROMPT_ID})

    with respx.mock:
        respx.post(f"{COMFYUI_URL}/prompt").mock(side_effect=fake_post)
        respx.get(f"{COMFYUI_URL}/history/{FAKE_PROMPT_ID}").mock(
            return_value=Response(200, json=make_history_response(FAKE_PROMPT_ID))
        )
        respx.get(f"{COMFYUI_URL}/view").mock(
            return_value=Response(200, content=b"fake-png-bytes")
        )

        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            await client.post(
                "/v1/images/generations",
                json={"prompt": "a red fox", "n": 1, "size": "512x512"},
            )

    wf = captured["workflow"]
    assert wf["4"]["inputs"]["text"] == "a red fox"
    assert wf["5"]["inputs"]["width"] == 512
    assert wf["5"]["inputs"]["height"] == 512
    assert wf["6"]["inputs"]["width"] == 512
    assert wf["6"]["inputs"]["height"] == 512


@pytest.mark.asyncio
async def test_api_key_required_when_configured(monkeypatch):
    monkeypatch.setenv("API_KEY", "secret-key")
    import importlib, main
    importlib.reload(main)

    async with AsyncClient(transport=ASGITransport(app=main.app), base_url="http://test") as client:
        r = await client.post(
            "/v1/images/generations",
            json={"prompt": "test"},
        )
    assert r.status_code == 401


@pytest.mark.asyncio
async def test_api_key_accepted_when_correct(monkeypatch):
    monkeypatch.setenv("API_KEY", "secret-key")
    import importlib, main
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

        async with AsyncClient(transport=ASGITransport(app=main.app), base_url="http://test") as client:
            r = await client.post(
                "/v1/images/generations",
                json={"prompt": "test"},
                headers={"Authorization": "Bearer secret-key"},
            )
    assert r.status_code == 200
