# MCPO Module

This module deploys MCPO (MCP-to-OpenAPI Proxy) to your Kubernetes cluster, providing OpenAPI endpoints for MCP (Model Context Protocol) servers.

## Features

- MCPO proxy server deployment via Kubernetes
- Docker socket access for MCP_DOCKER gateway
- Configurable MCP server support
- Auto-generated OpenAPI documentation
- Health checks and resource limits

## What is MCPO?

MCPO is a proxy server that converts MCP (Model Context Protocol) servers into standard OpenAPI REST endpoints. This allows:

- **Easy Integration**: Use MCP tools via familiar REST APIs
- **Auto Documentation**: Interactive OpenAPI docs at `/docs`
- **Cloud Deployment**: Deploy MCP tools in containerized environments
- **Standard HTTP**: No need for stdio or custom protocols

## Usage

### Basic Deployment

```hcl
module "mcpo" {
  source = "./modules/mcpo"

  project_name = "homelab"
  environment  = "production"
  namespace    = "homelab"
}
```

### With Custom Configuration

```hcl
module "mcpo" {
  source = "./modules/mcpo"

  project_name = "homelab"
  environment  = "production"
  namespace    = "homelab"
  
  cpu_limit    = "1000m"
  memory_limit = "1Gi"
  replicas     = 2
  
  enable_docker_socket = true
}
```

## Integration with Open WebUI

After deploying MCPO, configure Open WebUI to use the proxy:

```json
{
  "openapi_servers": [
    {
      "name": "MCPO",
      "url": "http://homelab-mcpo.homelab.svc.cluster.local:8000"
    }
  ]
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_name` | Project name for resource naming | `string` | `"homelab"` | no |
| `environment` | Environment name | `string` | `"dev"` | no |
| `namespace` | Kubernetes namespace | `string` | `"homelab"` | no |
| `replicas` | Number of MCPO replicas | `number` | `1` | no |
| `mcpo_image` | MCPO Docker image | `string` | `"python:3.11-slim"` | no |
| `cpu_limit` | CPU limit for MCPO | `string` | `"500m"` | no |
| `memory_limit` | Memory limit for MCPO | `string` | `"512Mi"` | no |
| `enable_docker_socket` | Enable Docker socket access | `bool` | `true` | no |
| `mcp_servers` | List of MCP servers to proxy | `list(object)` | See below | no |

### Default MCP Servers

```hcl
mcp_servers = [
  {
    name    = "docker"
    command = "docker"
    args    = ["mcp", "gateway", "run"]
  }
]
```

## Outputs

| Name | Description |
|------|-------------|
| `service_name` | MCPO service name |
| `service_url` | MCPO service URL for internal cluster access |
| `docs_url` | MCPO OpenAPI documentation URL |

## Security Considerations

⚠️ **Docker Socket Access**: When `enable_docker_socket` is true, the MCPO pod has access to the Docker socket, which provides significant privileges. Only enable in trusted environments.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| kubernetes | >= 2.0 |

## References

- [MCPO GitHub Repository](https://github.com/open-webui/mcpo)
- [Open WebUI MCP Documentation](https://docs.openwebui.com/openapi-servers/mcp)
- [Model Context Protocol](https://modelcontextprotocol.io/)
