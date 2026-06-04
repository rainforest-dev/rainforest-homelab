"""MCP transport wrapper for mcp-obsidian.

Serves MCP over Streamable HTTP (/mcp) and legacy SSE (/sse).
"""

import os
import logging

import anyio
from mcp.server.sse import SseServerTransport
from mcp.server.streamable_http import StreamableHTTPServerTransport
from starlette.applications import Starlette
from starlette.middleware import Middleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.routing import Route
import uvicorn

from mcp_obsidian.server import app

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("obsidian-mcp")


# --- Streamable HTTP (/mcp) ---

async def handle_mcp(request: Request):
    transport = StreamableHTTPServerTransport(mcp_session_id=None, is_json_response_enabled=False)
    async with transport.connect() as (read_stream, write_stream):
        async with anyio.create_task_group() as tg:
            async def run_server():
                await app.run(
                    read_stream, write_stream,
                    app.create_initialization_options(),
                    raise_exceptions=False,
                )

            tg.start_soon(run_server)
            await transport.handle_request(request.scope, request.receive, request._send)
            tg.cancel_scope.cancel()


# --- Legacy SSE (/sse + /message) ---

sse = SseServerTransport("/message")


async def handle_sse(request: Request):
    async with sse.connect_sse(request.scope, request.receive, request._send) as streams:
        await app.run(streams[0], streams[1], app.create_initialization_options())


async def handle_message(request: Request):
    return await sse.handle_post_message(request.scope, request.receive, request._send)


# --- Health ---

async def handle_health(request: Request):
    return JSONResponse({"status": "healthy", "server": "mcp-obsidian", "transport": "streamable-http+sse"})


# --- Middleware ---

class JsonNotFoundMiddleware(BaseHTTPMiddleware):
    """Return JSON for 404/405 to prevent OAuth discovery parse errors."""
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        if response.status_code in (404, 405):
            return JSONResponse({"error": "not_found"}, status_code=404)
        return response


starlette_app = Starlette(
    routes=[
        Route("/health", endpoint=handle_health),
        Route("/mcp", endpoint=handle_mcp, methods=["POST", "GET", "DELETE"]),
        Route("/sse", endpoint=handle_sse),
        Route("/message", endpoint=handle_message, methods=["POST"]),
    ],
    middleware=[Middleware(JsonNotFoundMiddleware)],
)

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8100"))
    logger.info(f"Starting mcp-obsidian on port {port} (Streamable HTTP + SSE)")
    uvicorn.run(starlette_app, host="0.0.0.0", port=port)
