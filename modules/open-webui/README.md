# Open WebUI Module

This module deploys Open WebUI with optional MCPO (Model Context Protocol for Open WebUI) integration to your Kubernetes cluster using Helm.

## Features

- Open WebUI deployment via Helm chart
- Optional Ollama integration
- Configurable resource limits and persistence
- **MCPO Integration** for Model Context Protocol support
- Docker socket access for container-based MCP services

## MCPO Integration

MCPO (Model Context Protocol for Open WebUI) allows you to integrate various AI tools and services with Open WebUI through the Model Context Protocol. This module supports:

### Docker Gateway Configuration

The module supports the Docker MCP gateway pattern, allowing you to run MCP services in containers. The default configuration includes:

```json
{
  "mcpServers": {
    "MCP_DOCKER": {
      "command": "docker",
      "args": ["mcp", "gateway", "run"],
      "type": "stdio"
    }
  }
}
```

### Security Considerations

When `enable_docker_socket` is set to `true`:

- The Docker socket (`/var/run/docker.sock`) is mounted into the Open WebUI pod
- The pod runs with elevated privileges (root user) to access the Docker socket
- This allows the container to launch and manage other Docker containers for MCP services

⚠️ **Security Warning**: Mounting the Docker socket provides significant privileges. Only enable this in trusted environments.

## Usage

### Basic Deployment

```hcl
module "open-webui" {
  source = "./modules/open-webui"

  project_name       = "homelab"
  environment        = "production"
  cpu_limit          = "500m"
  memory_limit       = "512Mi"
  enable_persistence = true
  storage_size       = "10Gi"
}
```

### With MCPO Integration

```hcl
module "open-webui" {
  source = "./modules/open-webui"

  project_name       = "homelab"
  environment        = "production"
  cpu_limit          = "500m"
  memory_limit       = "512Mi"
  enable_persistence = true
  storage_size       = "10Gi"

  # Enable MCPO
  mcpo_enabled         = true
  enable_docker_socket = true

  # Configure MCP servers
  mcp_servers_config = {
    MCP_DOCKER = {
      command = "docker"
      args = [
        "mcp",
        "gateway",
        "run"
      ]
      type = "stdio"
    }
    # Add more MCP servers as needed
    filesystem = {
      command = "npx"
      args = ["-y", "@modelcontextprotocol/server-filesystem", "/data"]
      type = "stdio"
    }
  }
}
```

## Variables

| Name                       | Description                                        | Type          | Default                         | Required |
| -------------------------- | -------------------------------------------------- | ------------- | ------------------------------- | :------: |
| `project_name`             | Project name for resource naming                   | `string`      | `"homelab"`                     |    no    |
| `environment`              | Environment name                                   | `string`      | `"dev"`                         |    no    |
| `namespace`                | Kubernetes namespace                               | `string`      | `"homelab"`                     |    no    |
| `cpu_limit`                | CPU limit for Open WebUI                           | `string`      | `"500m"`                        |    no    |
| `memory_limit`             | Memory limit for Open WebUI                        | `string`      | `"512Mi"`                       |    no    |
| `enable_persistence`       | Enable persistent storage                          | `bool`        | `true`                          |    no    |
| `storage_size`             | Storage size for Open WebUI                        | `string`      | `"10Gi"`                        |    no    |
| `chart_repository`         | Helm chart repository URL                          | `string`      | `"https://helm.openwebui.com/"` |    no    |
| `chart_name`               | Helm chart name                                    | `string`      | `"open-webui"`                  |    no    |
| `chart_version`            | Helm chart version                                 | `string`      | `null`                          |    no    |
| `create_namespace`         | Create namespace if it doesn't exist               | `bool`        | `true`                          |    no    |
| `ollama_enabled`           | Enable Ollama integration                          | `bool`        | `false`                         |    no    |
| **`mcpo_enabled`**         | **Enable MCPO integration**                        | `bool`        | `false`                         |    no    |
| **`enable_docker_socket`** | **Enable Docker socket access for MCP containers** | `bool`        | `false`                         |    no    |
| **`mcp_servers_config`**   | **Configuration for MCP servers**                  | `map(object)` | `{}`                            |    no    |

## Outputs

| Name          | Description                               |
| ------------- | ----------------------------------------- |
| `id`          | The ID of the Open Web UI resource        |
| `mcpo_config` | MCPO configuration details (when enabled) |

## Requirements

| Name       | Version |
| ---------- | ------- |
| terraform  | >= 1.0  |
| helm       | >= 2.0  |
| kubernetes | >= 2.0  |

## References

- [Open WebUI Documentation](https://docs.openwebui.com/)
- [MCPO GitHub Repository](https://github.com/open-webui/mcpo)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [MCPO Docker Integration Guide](https://github.com/open-webui/mcpo/discussions/86)
