# Docker MCP Gateway Terraform Solution

This document describes the Terraform-based solution for deploying Docker MCP Gateway as a remote MCP server accessible from Mac within the rainforest-homelab infrastructure.

## Overview

Docker MCP Gateway is Docker's implementation of the Model Context Protocol (MCP) that allows AI agents to interact with various tools and services. This solution deploys it as a Kubernetes service with remote access capabilities.

## Architecture

### Components
- **MCP Gateway**: Docker container running the MCP Gateway service
- **Configuration**: ConfigMap with MCP server definitions, tools, and gateway settings
- **Ingress**: Traefik IngressRoute for secure remote access
- **Service**: Kubernetes service for internal cluster communication
- **Security**: Kubernetes secrets for authentication

### Network Architecture
```
Mac Client → Traefik (HTTPS) → MCP Gateway → MCP Servers
                                     ↓
                               Docker Socket Proxy
```

## Deployment

### Prerequisites
- OrbStack Kubernetes cluster running
- Terraform installed and configured
- Traefik ingress controller deployed

### Step-by-Step Deployment

1. **Add Module to Main Configuration**
   ```hcl
   module "mcp-gateway" {
     source = "./modules/mcp-gateway"
     
     # Optional customizations
     transport_mode = "sse"
     gateway_port   = 8080
     enabled_tools  = ["docker", "playwright", "fetch"]
   }
   ```

2. **Deploy Infrastructure**
   ```bash
   cd /path/to/rainforest-homelab
   terraform init
   terraform plan
   terraform apply
   ```

3. **Verify Deployment**
   ```bash
   kubectl get pods -n homelab | grep mcp-gateway
   kubectl get services -n homelab | grep mcp-gateway
   ```

### Configuration Options

The module supports extensive customization through variables:

```hcl
module "mcp-gateway" {
  source = "./modules/mcp-gateway"
  
  # Basic configuration
  namespace      = "homelab"
  image_tag      = "latest"
  gateway_port   = 8080
  transport_mode = "sse"  # stdio, sse, streaming
  
  # Docker integration
  docker_host = "tcp://dockerproxy:2375"
  
  # MCP Servers
  mcp_servers = {
    docker = {
      image       = "mcp/docker"
      description = "Docker MCP server"
      environment = {}
    }
    custom-server = {
      image       = "your/custom-mcp-server"
      description = "Custom MCP server"
      environment = {
        API_KEY = "secret-value"
      }
    }
  }
  
  # Security
  security_block_network = false
  security_block_secrets = true
  cors_enabled          = true
  cors_origins          = ["https://yourdomain.com"]
  
  # Resources
  resource_limits = {
    cpu    = "2000m"
    memory = "4Gi"
  }
}
```

## Remote Access

### From Mac Client

The MCP Gateway is accessible via the following methods:

1. **HTTPS Endpoint**: `https://mcp-gateway.k8s.orb.local`
2. **Direct Port Forward** (for development):
   ```bash
   kubectl port-forward -n homelab svc/mcp-gateway 8080:80
   ```

### Transport Modes

1. **SSE (Server-Sent Events)** - Recommended for web clients
   - URL: `https://mcp-gateway.k8s.orb.local/sse`
   - Best for browser-based AI agents

2. **Streaming** - For real-time applications
   - URL: `https://mcp-gateway.k8s.orb.local/stream`
   - WebSocket-like communication

3. **stdio** - For direct process communication
   - Requires direct container access
   - Best for local development

## Security

### Authentication
- API key authentication via Kubernetes secrets
- Configurable CORS policies
- Network isolation options

### Network Security
- All traffic encrypted via Traefik HTTPS
- Docker socket access via secure proxy
- Configurable network blocking for tools

### Best Practices
1. **Change Default API Key**:
   ```bash
   kubectl patch secret mcp-gateway-secret -n homelab \
     --patch='{"data":{"api_key":"'$(echo -n "your-secure-key" | base64)'"}}'
   ```

2. **Restrict CORS Origins**:
   ```hcl
   cors_origins = ["https://your-trusted-domain.com"]
   ```

3. **Enable Network Blocking** for untrusted tools:
   ```hcl
   security_block_network = true
   ```

## MCP Servers

### Pre-configured Servers

1. **Docker Server** (`mcp/docker`)
   - Container management
   - Image operations
   - Network administration

2. **Playwright Server** (`mcp/playwright`)
   - Web automation
   - Browser testing
   - Page interaction

3. **Fetch Server** (`mcp/fetch`)
   - Web content retrieval
   - API calls
   - Data extraction

### Adding Custom Servers

1. **Via Terraform Variables**:
   ```hcl
   mcp_servers = {
     my-custom-server = {
       image       = "myorg/custom-mcp-server:latest"
       description = "Custom business logic server"
       environment = {
         API_ENDPOINT = "https://api.example.com"
         API_KEY      = var.custom_api_key
       }
     }
   }
   ```

2. **Via ConfigMap Update**:
   ```bash
   kubectl edit configmap mcp-gateway-config -n homelab
   ```

## Troubleshooting

### Common Issues

1. **Gateway Not Starting**
   ```bash
   kubectl logs -n homelab deployment/mcp-gateway
   kubectl describe pod -n homelab -l app=mcp-gateway
   ```

2. **Connection Refused**
   ```bash
   kubectl get endpoints -n homelab mcp-gateway
   kubectl port-forward -n homelab svc/mcp-gateway 8080:80
   curl http://localhost:8080/health
   ```

3. **MCP Server Not Available**
   ```bash
   kubectl exec -n homelab deployment/mcp-gateway -- \
     docker mcp gateway run --dry-run --verbose
   ```

### Health Checks

The gateway exposes health endpoints:
- `/health` - Overall gateway health
- `/ready` - Readiness for traffic
- `/metrics` - Prometheus metrics (if enabled)

### Logs and Monitoring

```bash
# Gateway logs
kubectl logs -n homelab deployment/mcp-gateway -f

# Configuration inspection
kubectl get configmap mcp-gateway-config -n homelab -o yaml

# Resource usage
kubectl top pod -n homelab -l app=mcp-gateway
```

## Performance Tuning

### Resource Allocation
```hcl
resource_limits = {
  cpu    = "2000m"    # Adjust based on workload
  memory = "4Gi"      # MCP servers can be memory intensive
}

resource_requests = {
  cpu    = "1000m"
  memory = "2Gi"
}
```

### Scaling Considerations
- MCP Gateway is stateless and can be horizontally scaled
- Consider persistent storage for long-lived MCP servers
- Monitor resource usage of individual MCP server containers

## Integration with Existing Services

### Docker Socket Access
The gateway connects to the existing Docker socket proxy for secure Docker operations:
```yaml
environment:
  DOCKER_HOST: tcp://dockerproxy:2375
```

### PostgreSQL Integration
For MCP servers requiring database access:
```hcl
mcp_servers = {
  database-server = {
    image = "mcp/postgresql"
    environment = {
      POSTGRES_HOST = "postgresql.homelab.svc.cluster.local"
      POSTGRES_DB   = "homelab"
    }
  }
}
```

## Comparison: Terraform vs Ansible

### Terraform Advantages (Recommended)
- **Declarative**: Infrastructure as code with state management
- **Integration**: Native Kubernetes provider support
- **Consistency**: Matches existing homelab architecture
- **Dependency Management**: Automatic resource ordering
- **Validation**: Built-in configuration validation

### Ansible Alternative

If Terraform is not feasible, here's an Ansible playbook structure:

```yaml
---
- name: Deploy MCP Gateway
  hosts: localhost
  vars:
    namespace: homelab
    gateway_port: 8080
  tasks:
    - name: Create namespace
      kubernetes.core.k8s:
        name: "{{ namespace }}"
        api_version: v1
        kind: Namespace
        state: present

    - name: Deploy ConfigMap
      kubernetes.core.k8s:
        definition:
          apiVersion: v1
          kind: ConfigMap
          metadata:
            name: mcp-gateway-config
            namespace: "{{ namespace }}"
          data:
            config.yaml: |
              version: "1.0"
              gateway:
                transport: sse
                port: {{ gateway_port }}
```

### Why Terraform is Preferred
1. **State Management**: Tracks infrastructure changes
2. **Provider Ecosystem**: Rich Kubernetes and Helm support
3. **Validation**: Compile-time configuration checking
4. **Modularity**: Reusable module architecture
5. **Integration**: Seamless with existing homelab setup

## Next Steps

1. **Monitor Performance**: Set up monitoring for resource usage
2. **Add Custom Servers**: Develop domain-specific MCP servers
3. **Enhance Security**: Implement fine-grained access controls
4. **Scale Horizontally**: Add multiple gateway replicas if needed
5. **Backup Configuration**: Include in existing backup strategies

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Kubernetes and Terraform logs
3. Consult Docker MCP Gateway documentation
4. File issues in the rainforest-homelab repository