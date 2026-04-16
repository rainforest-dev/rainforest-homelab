"""SSE transport wrapper for mcp-obsidian.

Imports the existing MCP server app and serves it over SSE
instead of stdio, enabling remote access via HTTP.
"""

import os
import logging

from mcp.server.sse import SseServerTransport
from starlette.applications import Starlette
from starlette.middleware import Middleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
from starlette.routing import Mount, Route
import uvicorn

# Import triggers tool registration and env var validation
from mcp_obsidian.server import app

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("obsidian-sse")

# Path must match the Mount path below so clients POST to the right endpoint
sse = SseServerTransport("/messages")


async def handle_sse(request):
    async with sse.connect_sse(request.scope, request.receive, request._send) as streams:
        await app.run(streams[0], streams[1], app.create_initialization_options())


async def handle_health(request):
    return JSONResponse({"status": "healthy", "server": "mcp-obsidian", "transport": "sse"})


class JsonNotFoundMiddleware(BaseHTTPMiddleware):
    """Return JSON for 404/405 responses (prevents OAuth discovery parse errors)."""
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        if response.status_code in (404, 405):
            return JSONResponse({"error": "not_found"}, status_code=404)
        return response


starlette_app = Starlette(
    routes=[
        Route("/health", endpoint=handle_health),
        Route("/sse", endpoint=handle_sse),
        # Mount as a raw ASGI app — handle_post_message already has the (scope, receive, send)
        # signature so no Starlette Request wrapper (and no _send private attribute) is needed.
        Mount("/messages", app=sse.handle_post_message),
    ],
    middleware=[Middleware(JsonNotFoundMiddleware)],
)

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8100"))
    logger.info(f"Starting mcp-obsidian SSE server on port {port}")
    uvicorn.run(starlette_app, host="0.0.0.0", port=port)
