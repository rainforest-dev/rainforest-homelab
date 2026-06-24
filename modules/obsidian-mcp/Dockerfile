FROM mcp/obsidian:latest
# Upgrade MCP SDK to get Streamable HTTP support (was 1.1.0, needs >=1.9)
RUN /usr/local/bin/pip3 install --target /app/.venv/lib/python3.12/site-packages --upgrade "mcp>=1.9" --quiet
