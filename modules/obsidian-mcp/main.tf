# Obsidian MCP Server — Streamable HTTP + legacy SSE
# Builds on mcp/obsidian:latest with upgraded MCP SDK (>=1.9 for Streamable HTTP)

resource "docker_image" "obsidian_mcp" {
  name = "obsidian-mcp:local"
  build {
    context    = path.module
    dockerfile = "Dockerfile"
  }
  triggers = {
    dockerfile = filemd5("${path.module}/Dockerfile")
  }
}

resource "docker_container" "obsidian_mcp" {
  image   = docker_image.obsidian_mcp.image_id
  name    = "${var.project_name}-obsidian-mcp"
  restart = "always"

  # Override entrypoint to use SSE wrapper instead of stdio
  entrypoint = ["/app/.venv/bin/python3", "/wrapper/sse_wrapper.py"]

  env = [
    "OBSIDIAN_API_KEY=${var.obsidian_api_key}",
    "OBSIDIAN_HOST=${var.docker_host_address}",
    "PORT=${var.port}",
  ]

  ports {
    internal = var.port
    external = var.port
    ip       = "127.0.0.1"
  }

  # Mount the SSE wrapper script
  volumes {
    host_path      = "${abspath(path.module)}/sse_wrapper.py"
    container_path = "/wrapper/sse_wrapper.py"
    read_only      = true
  }

  # Resource limits
  memory = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (
    can(regex("Gi", var.memory_limit)) ? 1024 * 1024 * 1024 :
    can(regex("Mi", var.memory_limit)) ? 1024 * 1024 : 1
  )

  lifecycle {
    ignore_changes = [memory_swap]
  }

  healthcheck {
    test         = ["CMD-SHELL", "python3 -c \"import urllib.request; urllib.request.urlopen('http://localhost:${var.port}/health')\" || exit 1"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "15s"
  }

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
    value = "obsidian-mcp"
  }
}
