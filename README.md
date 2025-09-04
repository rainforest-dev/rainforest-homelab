## Services

### PostgreSQL

- default port: 5432
- default user: postgres
- default password:

```bash
echo $(kubectl get secret --namespace homelab postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)
```

### Traefik

```bash
kubectl port-forward $(kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name --namespace=traefik) --namespace=traefik 8080:8080
```

### MCP Gateway

Docker MCP Gateway for AI agent interactions with remote access:

- **HTTPS Access**: `https://mcp-gateway.k8s.orb.local`
- **Transport Modes**: SSE (Server-Sent Events), Streaming, stdio
- **Pre-configured MCP Servers**: Docker, Playwright, Fetch

```bash
# Check MCP Gateway status
kubectl get pods -n homelab -l app=mcp-gateway

# View logs
kubectl logs -n homelab deployment/mcp-gateway

# Port forward for local access
kubectl port-forward -n homelab svc/mcp-gateway 8080:80

# Get API key
echo $(kubectl get secret --namespace homelab mcp-gateway-secret -o jsonpath="{.data.api_key}" | base64 --decode)
```

#### Available MCP Servers
- **Docker Server**: Container and image management via secure Docker socket proxy
- **Playwright Server**: Web automation and browser testing
- **Fetch Server**: Web content retrieval and API interactions

#### Usage from Mac
Connect your AI agent to: `https://mcp-gateway.k8s.orb.local`

See [MCP Gateway Setup Guide](docs/mcp-gateway-setup.md) for detailed configuration and usage instructions.