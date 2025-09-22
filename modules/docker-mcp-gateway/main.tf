# Docker MCP Gateway - Direct Docker Container
# Provides remote Docker MCP server accessible via Cloudflare Tunnel
# Follows the same pattern as dockerproxy for Docker-related services

resource "docker_container" "docker_mcp_gateway" {
  image   = var.docker_image
  name    = "${var.project_name}-docker-mcp-gateway"
  restart = "always"
  
  # Docker MCP Gateway command - uses tools.yaml for filtering
  command = [
    "--port", tostring(var.port),
    "--transport", "sse",
    "--verbose",
    "--watch",
    "--config", "/mcp/config.yaml",
    "--registry", "/mcp/registry.yaml",
    "--tools-config", "/mcp/tools.yaml"
  ]
  
  # Environment variables
  env = [
    "DOCKER_HOST=unix:///var/run/docker.sock",
    "MCP_DEBUG=${var.log_level == "debug" ? "true" : "false"}"
  ]
  
  # Port mapping for Cloudflare Tunnel access
  ports {
    internal = var.port
    external = var.port
    ip       = "127.0.0.1"  # Only bind to localhost for security
  }
  
  # Docker socket access (required for MCP operations)
  # SECURITY WARNING: This provides significant privileges equivalent to root access on the host
  # Consider these security mitigations:
  # - Deploy only in trusted environments
  # - Use OAuth authentication (configured via enable_auth in locals.tf) 
  # - Monitor container activities via logs
  # - Network isolation via Docker networks
  # - Alternative: Consider Docker-in-Docker (DinD) for enhanced isolation
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = false  # MCP Gateway needs write access for container operations
  }
  
  # Mount Docker MCP configuration
  # Uses existing ~/.docker/mcp for config.yaml and registry.yaml
  volumes {
    host_path      = "${pathexpand("~/.docker/mcp")}"
    container_path = "/mcp"
    read_only      = true
  }
  
  # Override tools.yaml with custom allowlist configuration
  volumes {
    host_path      = abspath("${path.module}/tools.yaml")
    container_path = "/mcp/tools.yaml"
    read_only      = true
  }
  
  
  # Resource limits - Docker expects memory in bytes
  memory = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (
    can(regex("Gi", var.memory_limit)) ? 1024 * 1024 * 1024 :
    can(regex("Mi", var.memory_limit)) ? 1024 * 1024 : 1
  )
  
  # Health check
  healthcheck {
    test = ["CMD-SHELL", "nc -z localhost ${var.port} || exit 1"]
    interval = "30s"
    timeout = "10s"
    retries = 3
    start_period = "30s"
  }
  
  # Labels for management
  labels {
    label = "project"
    value = var.project_name
  }
  
  labels {
    label = "environment"
    value = var.environment
  }
  
  labels {
    label = "service"
    value = "docker-mcp-gateway"
  }
  
  # Ensure Docker daemon is available
  depends_on = []
}