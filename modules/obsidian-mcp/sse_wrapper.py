"""SSE transport wrapper for mcp-obsidian.

Imports the existing MCP server app and serves it over SSE
instead of stdio, enabling remote access via HTTP.
"""

import os
import asyncio
import logging

from mcp.server.sse import SseServerTransport
from starlette.applications import Starlette
from starlette.routing import Route
from starlette.responses import JSONResponse
import uvicorn

# Import triggers tool registration and env var validation
from mcp_obsidian.server import app

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("obsidian-sse")

sse = SseServerTransport("/message")


async def handle_sse(request):
    async with sse.connect_sse(request.scope, request.receive, request._send) as streams:
        await app.run(streams[0], streams[1], app.create_initialization_options())


async def handle_health(request):
    return JSONResponse({"status": "healthy", "server": "mcp-obsidian", "transport": "sse"})


from starlette.middleware import Middleware
from starlette.middleware.base import BaseHTTPMiddleware


class JsonNotFoundMiddleware(BaseHTTPMiddleware):
    """Return JSON for 404/405 responses (prevents OAuth discovery parse errors)."""
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        if response.status_code in (404, 405):
            return JSONResponse({"error": "not_found"}, status_code=404)
        return response


async def handle_message(request):
    return await sse.handle_post_message(request.scope, request.receive, request._send)


starlette_app = Starlette(
    routes=[
        Route("/health", endpoint=handle_health),
        Route("/sse", endpoint=handle_sse),
        Route("/message", endpoint=handle_message, methods=["POST"]),
    ],
    middleware=[Middleware(JsonNotFoundMiddleware)],
)

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8100"))
    logger.info(f"Starting mcp-obsidian SSE server on port {port}")
    uvicorn.run(starlette_app, host="0.0.0.0", port=port)
