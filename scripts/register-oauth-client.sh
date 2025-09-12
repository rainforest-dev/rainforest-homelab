#!/bin/bash

# OAuth Client Registration Script for Terraform
# This script registers a persistent OAuth client for Claude MCP authentication

set -e

# Default values (can be overridden by environment variables)
OAUTH_WORKER_URL=${OAUTH_WORKER_URL:-"https://docker-mcp.rainforest.tools"}
CLIENT_NAME=${CLIENT_NAME:-"Claude"}
REDIRECT_URI=${REDIRECT_URI:-"https://claude.ai/api/mcp/auth_callback"}

echo "=== OAuth Client Registration ==="
echo "Worker URL: $OAUTH_WORKER_URL"
echo "Client Name: $CLIENT_NAME"
echo "Redirect URI: $REDIRECT_URI"
echo

# Register the client
response=$(curl -s -X POST "$OAUTH_WORKER_URL/register" \
  -H "Content-Type: application/json" \
  -d "{\"client_name\": \"$CLIENT_NAME\", \"redirect_uris\": [\"$REDIRECT_URI\"]}")

# Check if registration was successful
if echo "$response" | grep -q '"client_id"'; then
    echo "✅ OAuth client registered successfully!"
    echo
    echo "Client Registration Details:"
    echo "$response" | jq .
    echo
    echo "=== MCP Configuration ==="
    echo "Use these credentials in your MCP client configuration:"
    echo
    client_id=$(echo "$response" | jq -r '.client_id')
    client_secret=$(echo "$response" | jq -r '.client_secret')
    
    echo "{"
    echo "  \"mcpServers\": {"
    echo "    \"docker-remote\": {"
    echo "      \"type\": \"sse\","
    echo "      \"url\": \"$OAUTH_WORKER_URL/sse\","
    echo "      \"oauth\": {"
    echo "        \"client_id\": \"$client_id\","
    echo "        \"client_secret\": \"$client_secret\""
    echo "      }"
    echo "    }"
    echo "  }"
    echo "}"
    echo
    echo "=== Terraform Outputs ==="
    echo "Add these to your terraform.tfvars if needed:"
    echo "claude_oauth_client_id     = \"$client_id\""
    echo "claude_oauth_client_secret = \"$client_secret\""
else
    echo "❌ Failed to register OAuth client"
    echo "Response: $response"
    exit 1
fi