# Docker MCP Gateway Module

This module deploys a remote Docker MCP (Model Context Protocol) Gateway to your Kubernetes cluster, providing secure remote access to Docker operations via the MCP protocol.

## Features

- **Remote Docker MCP Server**: Kubernetes-based deployment accessible from anywhere
- **Cloudflare Tunnel Integration**: Secure external access without exposing home IP
- **Docker Socket Access**: Full Docker operations via MCP protocol
- **Security Controls**: Network policies, RBAC, and minimal privileges
- **Health Monitoring**: Built-in health checks and optional metrics
- **Standardized Configuration**: Follows homelab module patterns

## What is Docker MCP Gateway?

The Docker MCP Gateway provides a standardized way to access Docker operations remotely through the Model Context Protocol (MCP). This allows:

- **Remote Docker Control**: Manage containers from any location
- **Secure Access**: Authentication via Cloudflare Zero Trust
- **API Standardization**: Consistent Docker operations via MCP protocol
- **Multi-Client Support**: Access from various MCP-compatible clients

## Architecture

```
Mac Client → Cloudflare Edge → Tunnel → K8s Service → Docker MCP Gateway → Docker Socket
```

The gateway runs in Kubernetes with access to the Docker socket, providing secure remote Docker operations.

## Usage

### Basic Deployment

```hcl
module "docker_mcp_gateway" {
  source = "./modules/docker-mcp-gateway"

  project_name = "homelab"
  environment  = "production"
  namespace    = "homelab"
}
```

### Production Configuration

```hcl
module "docker_mcp_gateway" {
  source = "./modules/docker-mcp-gateway"

  project_name = "homelab"
  environment  = "production"
  namespace    = "homelab"
  
  # Resource configuration
  cpu_limit    = "1000m"
  memory_limit = "1Gi"
  replicas     = 2
  
  # External access
  enable_cloudflare_tunnel = true
  tunnel_hostname         = "docker-mcp"
  domain_suffix          = "yourdomain.com"
  
  # Security
  enable_network_policy = true
  enable_docker_socket  = true
  log_level            = "info"
  
  # Monitoring
  enable_metrics      = true
  enable_health_checks = true
}
```

### Integration with Cloudflare Tunnel

To enable external access, add the Docker MCP Gateway to your Cloudflare Tunnel configuration:

```hcl
# In modules/cloudflare-tunnel/main.tf
ingress_rule {
  hostname = "docker-mcp.${var.domain_suffix}"
  service  = "http://homelab-docker-mcp-gateway.homelab.svc.cluster.local:8080"
}
```

And add to DNS records:

```hcl
# In modules/cloudflare-tunnel/main.tf  
services = [
  "homepage",
  "open-webui", 
  "flowise",
  "n8n",
  "docker-mcp"  # Add this line
]
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| **`project_name`** | **Project name for resource naming** | `string` | `"homelab"` | no |
| **`environment`** | **Environment name** | `string` | `"production"` | no |
| **`namespace`** | **Kubernetes namespace** | `string` | `"homelab"` | no |
| **`replicas`** | **Number of Docker MCP Gateway replicas** | `number` | `1` | no |
| **`docker_image`** | **Docker image for the container** | `string` | `"alpine:3.19"` | no |
| **`port`** | **Port for Docker MCP Gateway service** | `number` | `8080` | no |
| **`cpu_limit`** | **CPU limit** | `string` | `"500m"` | no |
| **`memory_limit`** | **Memory limit** | `string` | `"512Mi"` | no |
| **`log_level`** | **Log level (debug/info/warn/error)** | `string` | `"info"` | no |
| **`docker_timeout`** | **Timeout for Docker operations** | `number` | `30` | no |
| **`enable_network_policy`** | **Enable Kubernetes network policy** | `bool` | `false` | no |
| **`enable_docker_socket`** | **Enable Docker socket access** | `bool` | `true` | no |
| **`enable_cloudflare_tunnel`** | **Enable access via Cloudflare Tunnel** | `bool` | `true` | no |
| **`tunnel_hostname`** | **Hostname for Cloudflare Tunnel** | `string` | `"docker-mcp"` | no |
| **`domain_suffix`** | **Domain suffix for external access** | `string` | `""` | no |
| **`enable_metrics`** | **Enable Prometheus metrics** | `bool` | `false` | no |
| **`enable_health_checks`** | **Enable health check endpoints** | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| `resource_id` | Docker MCP Gateway deployment ID |
| `service_name` | Docker MCP Gateway service name |
| `service_url` | Internal cluster service URL |
| `external_url` | External URL via Cloudflare Tunnel |
| `namespace` | Kubernetes namespace |
| `cluster_ip` | Service cluster IP |
| `port` | Service port |

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

### From Mac (using MCP client)

```json
{
  "mcpServers": {
    "docker-remote": {
      "command": "mcp-client",
      "args": ["--server", "https://docker-mcp.yourdomain.com"],
      "type": "http"
    }
  }
}
```

### Using curl for testing

```bash
# Health check
curl https://docker-mcp.yourdomain.com/health

# List containers (example MCP call)
curl -X POST https://docker-mcp.yourdomain.com/mcp/call \
  -H "Content-Type: application/json" \
  -d '{"method": "docker.container.list", "params": {}}'
```

## Troubleshooting

### Common Issues

**1. Container fails to start**
```bash
# Check pod logs
kubectl logs -n homelab -l app=docker-mcp-gateway

# Check events
kubectl get events -n homelab --sort-by='.lastTimestamp'
```

**2. Docker socket permission denied**
```bash
# Verify Docker socket exists
kubectl exec -n homelab deployment/homelab-docker-mcp-gateway -- ls -la /var/run/docker.sock

# Check security context
kubectl get pod -n homelab -l app=docker-mcp-gateway -o yaml | grep -A 10 securityContext
```

**3. External access not working**
```bash
# Check Cloudflare Tunnel status
kubectl logs -n homelab -l app=cloudflared

# Verify tunnel configuration
kubectl get configmap -n homelab cloudflared-config -o yaml
```

**4. Network connectivity issues**
```bash
# Test internal connectivity
kubectl run test-pod --rm -it --restart=Never --image=alpine -- \
  wget -qO- http://homelab-docker-mcp-gateway.homelab.svc.cluster.local:8080/health
```

### Health Checks

The module includes comprehensive health monitoring:

- **Liveness Probe**: `/health` endpoint
- **Readiness Probe**: `/ready` endpoint
- **Metrics** (optional): `/metrics` endpoint

### Logs and Monitoring

```bash
# View application logs
kubectl logs -n homelab -l app=docker-mcp-gateway -f

# Check resource usage
kubectl top pods -n homelab -l app=docker-mcp-gateway

# View metrics (if enabled)
curl http://homelab-docker-mcp-gateway.homelab.svc.cluster.local:9090/metrics
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

- Docker Desktop Kubernetes cluster
- Cloudflare Tunnel (for external access)
- Docker socket available on nodes

## References

- [Docker MCP Gateway Documentation](https://docs.docker.com/ai/mcp-gateway/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Kubernetes Security Contexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)