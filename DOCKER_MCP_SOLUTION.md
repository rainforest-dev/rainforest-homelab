# Docker MCP Gateway - Simple and Secure Solution

## Summary

A **simple Docker container** solution for exposing local Docker MCP servers via the official Docker MCP Gateway with secure external access through Cloudflare Tunnel.

## Architecture

```
Remote MCP Client → Cloudflare Edge → Tunnel → Docker Host → Docker MCP Gateway → Docker Socket
```

### Key Components

- **Docker Container**: Official `docker/mcp-gateway:latest` image 
- **Cloudflare Tunnel**: Secure external access (no port forwarding)
- **Zero Trust Auth**: Optional email-based authentication
- **Direct Socket Access**: Efficient Docker operations

## Why Docker Container vs Kubernetes?

✅ **Simpler**: Single container vs 5+ Kubernetes resources  
✅ **Efficient**: No pod/service/RBAC overhead (~1GB less memory)  
✅ **Consistent**: Follows existing `dockerproxy` pattern  
✅ **Faster**: No scheduling delays, direct socket access  
✅ **Easier**: Standard `docker logs` and troubleshooting  

## Quick Start

### 1. Enable in Terraform

```hcl
# terraform.tfvars
enable_docker_mcp_gateway = true
enable_cloudflare_tunnel = true
domain_suffix = "yourdomain.com"
cloudflare_account_id = "your-account-id"
cloudflare_api_token = "your-api-token"

# Optional authentication
allowed_email_domains = ["yourdomain.com"]
```

### 2. Deploy

```bash
terraform apply -target="module.docker_mcp_gateway"
```

### 3. Verify

```bash
# Check container
docker ps | grep docker-mcp-gateway

# Test local access
curl -I http://localhost:3000

# Test external access
curl -I https://docker-mcp.yourdomain.com
```

## Client Configuration

### VS Code MCP Extension
```json
{
  "mcp.servers": {
    "docker-remote": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-docker"],
      "env": {
        "DOCKER_HOST": "https://docker-mcp.yourdomain.com"
      }
    }
  }
}
```

### Claude Desktop
```json
{
  "mcpServers": {
    "docker-remote": {
      "command": "npx", 
      "args": ["-y", "@modelcontextprotocol/server-docker"],
      "env": {
        "DOCKER_HOST": "https://docker-mcp.yourdomain.com"
      }
    }
  }
}
```

### Direct API Access
```bash
curl -X POST https://docker-mcp.yourdomain.com/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "docker_container_list",
      "arguments": {}
    }
  }'
```

## Management Commands

### Container Operations
```bash
# View logs
docker logs homelab-docker-mcp-gateway -f

# Check resources
docker stats homelab-docker-mcp-gateway

# Restart container
docker restart homelab-docker-mcp-gateway

# Update image
docker pull docker/mcp-gateway:latest
terraform apply -replace="module.docker_mcp_gateway[0].docker_container.docker_mcp_gateway"
```

### Troubleshooting
```bash
# Container won't start
docker logs homelab-docker-mcp-gateway
docker inspect homelab-docker-mcp-gateway

# Docker socket access issues
docker exec homelab-docker-mcp-gateway ls -la /var/run/docker.sock
docker exec homelab-docker-mcp-gateway docker version

# Network connectivity
curl -I http://localhost:3000
netstat -tlnp | grep :3000
```

## Security Features

- **Localhost Binding**: Only accessible on 127.0.0.1:3000
- **Cloudflare Tunnel**: No direct port exposure 
- **Zero Trust Auth**: Email-based access control
- **Resource Limits**: Memory constraints (512Mi default)
- **Health Monitoring**: Built-in health checks
- **Restart Policy**: Automatic recovery (`unless-stopped`)

## No Automation Needed

With Docker containers, **manual Ansible automation is unnecessary**:

- **Updates**: Simple `docker pull` + `terraform apply -replace`
- **Health**: Built-in Docker health checks
- **Logs**: Standard `docker logs` command  
- **Restart**: Docker restart policies handle recovery
- **Scaling**: Not needed for single-user scenarios

For version management, use standard Docker workflows:

```bash
# Check for updates
docker pull docker/mcp-gateway:latest

# Apply updates  
terraform apply -replace="module.docker_mcp_gateway[0].docker_container.docker_mcp_gateway"
```

## Production Recommendations

1. **Pin Image Version**: Use specific tags instead of `latest`
2. **Enable Zero Trust**: Add email authentication
3. **Monitor Logs**: Set up log aggregation
4. **Backup Config**: Include in backup strategy
5. **Resource Limits**: Adjust memory based on usage

## References

- [Module Documentation](modules/docker-mcp-gateway/README.md)
- [Official Docker MCP Gateway](https://hub.docker.com/r/docker/mcp-gateway)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

---

**Status**: Production Ready  
**Approach**: Simple Docker Container  
**Last Updated**: September 8, 2025  

## Security Architecture

### Network Security
- **Localhost Binding**: Container only binds to 127.0.0.1:3000
- **Cloudflare Tunnel**: Only external access method (no port forwarding)
- **TLS Termination**: Handled at Cloudflare edge
- **No Direct Exposure**: Port not accessible from external networks

### Access Control
- **Cloudflare Zero Trust**: Email domain/address-based authentication
- **Docker Socket**: Mounted with appropriate permissions
- **Container Isolation**: Standard Docker container isolation
- **Health Monitoring**: Built-in health checks with restart policies

### Container Security
- **Resource Limits**: Memory constraints (configurable)
- **Health Checks**: netcat-based health monitoring
- **Restart Policy**: `unless-stopped` for resilience
- **Labels**: Proper container labeling for management

## Configuration

### 1. Enable the Module

In your `terraform.tfvars`:

```hcl
enable_docker_mcp_gateway = true
enable_cloudflare_tunnel = true
domain_suffix = "yourdomain.com"
cloudflare_account_id = "your-account-id"
cloudflare_api_token = "your-api-token"
```

### 2. Authentication (Optional)

For Zero Trust access control:

```hcl
allowed_email_domains = ["yourdomain.com"]
# or
allowed_emails = ["admin@yourdomain.com"]
```

### 3. Deploy

```bash
terraform plan
terraform apply
```

## Client Configuration

### VS Code with MCP Extension

```json
{
  "mcp.servers": {
    "docker-remote": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-docker"],
      "env": {
        "DOCKER_HOST": "https://docker-mcp.yourdomain.com"
      }
    }
  }
}
```

### Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "docker-remote": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-docker"],
      "env": {
        "DOCKER_HOST": "https://docker-mcp.yourdomain.com"
      }
    }
  }
}
```

### Direct HTTP Access

```bash
# List containers
curl -X POST https://docker-mcp.yourdomain.com/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "docker_container_list",
      "arguments": {}
    }
  }'

# Execute Docker command
curl -X POST https://docker-mcp.yourdomain.com/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "docker_exec",
      "arguments": {
        "command": "docker ps"
      }
    }
  }'
```

### Python MCP Client

```python
import httpx
import asyncio

async def docker_mcp_client():
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://docker-mcp.yourdomain.com/rpc",
            json={
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/list"
            }
        )
        print("Available tools:", response.json())

asyncio.run(docker_mcp_client())
```

## Deployment and Testing

### 1. Deploy the Gateway

```bash
cd /path/to/rainforest-homelab
terraform apply -target="module.docker_mcp_gateway"
```

### 2. Verify Deployment

```bash
# Check container status
docker ps | grep docker-mcp-gateway

# Check logs
docker logs homelab-docker-mcp-gateway

# Test local connectivity
curl -I http://localhost:3000
```

### 3. Test External Access

```bash
# Test external URL (after tunnel deployment)
curl -I https://docker-mcp.yourdomain.com

# Test with authentication (if Zero Trust enabled)
curl -H "CF-Access-Token: YOUR_TOKEN" \
  https://docker-mcp.yourdomain.com/rpc
```

## Troubleshooting

### Common Issues

1. **Container Won't Start**
   ```bash
   docker logs homelab-docker-mcp-gateway
   docker inspect homelab-docker-mcp-gateway
   ```

2. **Docker Socket Permission Denied**
   ```bash
   # Check socket permissions
   docker exec homelab-docker-mcp-gateway ls -la /var/run/docker.sock
   
   # Test Docker access
   docker exec homelab-docker-mcp-gateway docker version
   ```

3. **External Access Issues**
   ```bash
   # Check tunnel status
   kubectl logs -n homelab -l app=cloudflared
   
   # Test local access
   curl -I http://localhost:3000
   
   # Verify DNS resolution
   nslookup docker-mcp.yourdomain.com
   ```

### Health Checks

The gateway includes comprehensive monitoring:

- **Docker Health Check**: netcat test on port 3000 (every 30s)
- **Restart Policy**: `unless-stopped` for automatic recovery
- **Resource Limits**: Memory constraints to prevent resource exhaustion

### Logs and Metrics

```bash
# View application logs
docker logs homelab-docker-mcp-gateway -f

# Check resource usage
docker stats homelab-docker-mcp-gateway

# Container inspection
docker inspect homelab-docker-mcp-gateway
```

## Security Considerations

### Risk Assessment

⚠️ **HIGH PRIVILEGE**: Docker socket access provides significant container privileges:
- Container lifecycle management (create, start, stop, delete)
- Image operations (pull, build, push)
- Volume and network management
- Potential host filesystem access via volume mounts

### Mitigation Strategies

1. **Network Isolation**: Use Cloudflare Tunnel (never direct exposure)
2. **Authentication**: Enable Zero Trust email verification
3. **Monitoring**: Log all Docker operations
4. **Principle of Least Privilege**: Limit allowed operations where possible
5. **Regular Audits**: Monitor container activities

### Best Practices

- Deploy only in trusted environments
- Use specific Docker image tags (not `latest`) in production
- Enable network policies in production
- Regularly update container images
- Monitor authentication logs in Cloudflare
- Implement proper backup strategies for Docker volumes

## Production Hardening

### Enhanced Security

```hcl
module "docker_mcp_gateway" {
  source = "./modules/docker-mcp-gateway"

  # Production configuration
  project_name = "homelab"
  environment  = "production"
  namespace    = "homelab"
  
  # Specific image version (not latest)
  docker_image = "docker/mcp-gateway:1.0.0"
  
  # Resource limits
  cpu_limit    = "1000m"
  memory_limit = "1Gi"
  replicas     = 2
  
  # Security hardening
  enable_network_policy = true
  log_level            = "info"  # or "warn" for production
  
  # External access
  enable_cloudflare_tunnel = true
  tunnel_hostname         = "docker-mcp"
  domain_suffix          = "yourdomain.com"
}
```

### Monitoring and Alerting

Consider implementing:
- Prometheus metrics collection
- Grafana dashboards for resource usage
- Alerting for failed deployments
- Log aggregation (e.g., ELK stack)

## References

- [Official Docker MCP Gateway](https://hub.docker.com/r/docker/mcp-gateway)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)

---

**Last Updated**: September 8, 2025  
**Status**: Production Ready  
**Maintainer**: Rainforest Homelab Team