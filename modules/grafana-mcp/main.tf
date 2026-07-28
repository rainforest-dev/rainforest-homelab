resource "docker_image" "grafana_mcp" {
  name         = "grafana/mcp-grafana:${var.image_version}"
  keep_locally = true
}

resource "docker_container" "grafana_mcp" {
  name  = "${var.project_name}-grafana-mcp"
  image = docker_image.grafana_mcp.image_id

  restart = "always"

  # The image's default CMD ignores env-based port config — it only listens on
  # the port passed via -address, defaulting to localhost:8000 otherwise.
  command = ["-t", "sse", "-address", "0.0.0.0:${var.mcp_port}"]

  ports {
    internal = var.mcp_port
    external = var.mcp_port
    protocol = "tcp"
  }

  env = [
    "GRAFANA_URL=${var.grafana_url}",
    "GRAFANA_API_KEY=${var.grafana_api_key}",
  ]

  memory = 64

  lifecycle {
    ignore_changes = [memory_swap]
  }

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "bash", "-c", "echo > /dev/tcp/localhost/${var.mcp_port}"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "20s"
  }
}
