# Docker MCP Gateway Module

This module deploys a Docker MCP (Model Context Protocol) Gateway as a **simple Docker container**, providing secure remote access to Docker operations via the MCP protocol.

## Features

- **Direct Docker Container**: Simple, efficient deployment (no Kubernetes overhead)
- **Cloudflare Tunnel Integration**: Secure external access without exposing home IP
- **Docker Socket Access**: Full Docker operations via MCP protocol
- **Health Monitoring**: Built-in health checks and restart policies
- **Resource Management**: Memory limits and Docker health checks
- **Localhost Security**: Only binds to 127.0.0.1 for secure local access

## What is Docker MCP Gateway?

The Docker MCP Gateway provides a standardized way to access Docker operations remotely through the Model Context Protocol (MCP). This allows:

- **Remote Docker Control**: Manage containers from any location
- **Secure Access**: Authentication via Cloudflare Zero Trust
- **API Standardization**: Consistent Docker operations via MCP protocol
- **Multi-Client Support**: Access from various MCP-compatible clients

## Architecture

```
Mac Client → Cloudflare Edge → Tunnel → Docker Host → Docker MCP Gateway → Docker Socket
```

The gateway runs as a **simple Docker container** with access to the Docker socket, providing secure remote Docker operations without Kubernetes complexity.

## Usage

### Basic Deployment

```hcl
module "docker_mcp_gateway" {
  source = "./modules/docker-mcp-gateway"

  project_name = "homelab"
  environment  = "production"
}
```

### Production Configuration

```hcl
module "docker_mcp_gateway" {
  source = "./modules/docker-mcp-gateway"

  project_name = "homelab"
  environment  = "production"
  
  # Resource configuration
  memory_limit = "1Gi"
  
  # External access
  enable_cloudflare_tunnel = true
  tunnel_hostname         = "docker-mcp"
  domain_suffix          = "yourdomain.com"
  
  # Logging
  log_level = "info"
}
```

### Integration with Cloudflare Tunnel

The Docker container is automatically accessible via Cloudflare Tunnel:

```hcl
# In modules/cloudflare-tunnel/main.tf (already configured)
ingress_rule {
  hostname = "docker-mcp.${var.domain_suffix}"
  service  = "http://host.docker.internal:3000"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| **`project_name`** | **Project name for resource naming** | `string` | `"homelab"` | no |
| **`environment`** | **Environment name** | `string` | `"production"` | no |
| **`docker_image`** | **Docker image for the container** | `string` | `"docker/mcp-gateway:latest"` | no |
| **`port`** | **Port for Docker MCP Gateway service** | `number` | `3000` | no |
| **`memory_limit`** | **Memory limit (e.g., 512Mi, 1Gi)** | `string` | `"512Mi"` | no |
| **`log_level`** | **Log level (debug/info/warn/error)** | `string` | `"info"` | no |
| **`enable_cloudflare_tunnel`** | **Enable access via Cloudflare Tunnel** | `bool` | `true` | no |
| **`tunnel_hostname`** | **Hostname for Cloudflare Tunnel** | `string` | `"docker-mcp"` | no |
| **`domain_suffix`** | **Domain suffix for external access** | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| `resource_id` | Docker MCP Gateway container ID |
| `container_name` | Docker MCP Gateway container name |
| `service_url` | Local service URL (http://localhost:3000) |
| `external_url` | External URL via Cloudflare Tunnel |
| `port` | Service port |
| `image` | Docker image used |
| `container_status` | Container running status |

## Security Considerations

### Docker Socket Access

⚠️ **Critical Security Warning**: This module requires Docker socket access to function, which provides significant privileges:

- **Container Management**: Can create, modify, and delete containers
- **Image Operations**: Can pull, build, and manage Docker images  
- **Host Access**: Potential access to host filesystem via volume mounts
- **Privilege Escalation**: Can run privileged containers

**Mitigation Strategies:**
- Deploy only in trusted environments
- Use network policies to restrict access
- Enable Cloudflare Zero Trust authentication
- Monitor container activities via logs
- Limit allowed Docker operations via configuration

### Network Security

- **Default**: ClusterIP service (internal only)
- **External Access**: Only via Cloudflare Tunnel (no direct exposure)
- **Network Policies**: Optional but recommended for production
- **TLS Termination**: Handled by Cloudflare Edge

### Authentication

Configure Cloudflare Zero Trust for secure access:

```hcl
# In terraform.tfvars
allowed_email_domains = ["yourdomain.com"]
# or
allowed_emails = ["admin@yourdomain.com"]
```

## Client Configuration

### VS Code MCP Client Setup

1. **Install VS Code Extension**: Install the MCP Client extension from the marketplace
2. **Configure MCP Server**: Add the following to your VS Code settings:

```json
{
  "mcp.server.docker-remote": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/client", "connect", "https://docker-mcp.rainforest.tools"],
    "type": "http"
  }
}
```

3. **Authenticate**: When prompted, authenticate with your Cloudflare Zero Trust credentials
4. **Verify Connection**: Check the MCP output panel for successful connection

### Claude Desktop Configuration

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "docker-remote": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/client", "connect", "https://docker-mcp.rainforest.tools"],
      "type": "http"
    }
  }
}
```

### Direct HTTP API Usage

The Docker MCP Gateway exposes a REST API that you can use directly:

```bash
# List containers
curl -X POST https://docker-mcp.rainforest.tools/mcp/docker/container/list \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"

# Get container logs
curl -X POST https://docker-mcp.rainforest.tools/mcp/docker/container/logs \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"container": "container_name"}'

# Execute Docker command
curl -X POST https://docker-mcp.rainforest.tools/mcp/docker/exec \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"command": "docker ps", "detach": false}'
```

### Python MCP Client

```python
import httpx
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    # Connect to remote Docker MCP Gateway
    async with httpx.AsyncClient() as http_client:
        response = await http_client.post(
            "https://docker-mcp.rainforest.tools/mcp/connect",
            json={"type": "docker"}
        )
        
        if response.status_code == 200:
            print("Connected to Docker MCP Gateway")
            
            # List available tools
            tools_response = await http_client.get(
                "https://docker-mcp.rainforest.tools/mcp/tools"
            )
            print("Available tools:", tools_response.json())

if __name__ == "__main__":
    asyncio.run(main())
```

### JavaScript/TypeScript MCP Client

```typescript
import { Client } from '@modelcontextprotocol/client';

const client = new Client({
  name: 'docker-remote-client',
  version: '1.0.0'
});

// Connect to remote gateway
await client.connect('https://docker-mcp.rainforest.tools');

// List containers
const containers = await client.callTool({
  name: 'docker-container-list',
  arguments: {}
});

console.log('Containers:', containers);
```

### Authentication

The Docker MCP Gateway uses Cloudflare Zero Trust for authentication. Make sure your client supports:

- **Bearer Token Authentication**: Include `Authorization: Bearer <token>` header
- **Cloudflare Access Tokens**: Use tokens obtained from Cloudflare Access
- **Email-based Authentication**: Authenticate with allowed email domains

### Security Best Practices

1. **Use HTTPS Only**: Always connect via HTTPS (enforced by Cloudflare)
2. **Token Rotation**: Regularly rotate authentication tokens
3. **Network Restrictions**: Only allow access from trusted networks
4. **Monitor Usage**: Enable logging and monitoring for security events
5. **Principle of Least Privilege**: Limit Docker operations to necessary ones only

## Troubleshooting

### Common Issues

**1. Container fails to start**
```bash
# Check container logs
docker logs homelab-docker-mcp-gateway

# Check container status
docker ps -a | grep docker-mcp-gateway
```

**2. Docker socket permission denied**
```bash
# Verify Docker socket exists and is accessible
docker exec homelab-docker-mcp-gateway ls -la /var/run/docker.sock

# Test Docker socket access
docker exec homelab-docker-mcp-gateway docker version
```

**3. External access not working**
```bash
# Check Cloudflare Tunnel status
kubectl logs -n homelab -l app=cloudflared

# Test local connectivity
curl -I http://localhost:3000
```

**4. Network connectivity issues**
```bash
# Test internal connectivity
docker exec homelab-docker-mcp-gateway nc -zv localhost 3000

# Check if port is bound
netstat -tlnp | grep :3000
```

### Health Checks

The module includes comprehensive health monitoring:

- **Docker Health Check**: Built-in netcat check on port 3000
- **Restart Policy**: `unless-stopped` for automatic recovery
- **Resource Limits**: Memory constraints to prevent resource exhaustion

### Logs and Monitoring

```bash
# View application logs
docker logs homelab-docker-mcp-gateway -f

# Check resource usage
docker stats homelab-docker-mcp-gateway

# Container inspection
docker inspect homelab-docker-mcp-gateway
```

## Requirements

| Name | Version |
|------|---------| 
| terraform | >= 1.0 |
| kubernetes | >= 2.0 |

## Providers

| Name | Version |
|------|---------| 
| kubernetes | >= 2.0 |

## Dependencies

- Docker Engine running on the host
- Cloudflare Tunnel (for external access)
- Docker socket available at `/var/run/docker.sock`

## References

- [Docker MCP Gateway Documentation](https://docs.docker.com/ai/mcp-gateway/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Kubernetes Security Contexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)