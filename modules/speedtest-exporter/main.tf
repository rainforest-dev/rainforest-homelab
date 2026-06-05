resource "docker_image" "speedtest_exporter" {
  name         = "ghcr.io/miguelndecarvalho/speedtest-exporter:${var.image_version}"
  keep_locally = true
}

resource "docker_container" "speedtest_exporter" {
  name  = "${var.project_name}-speedtest-exporter"
  image = docker_image.speedtest_exporter.image_id

  restart = "unless-stopped"

  ports {
    internal = 9798
    external = var.port
    protocol = "tcp"
  }

  # Run on host network so it uses the Mac Mini's wired Ethernet for accurate ISP results
  # (avoids Docker bridge NAT overhead)
  network_mode = "host"

  memory     = 128
  cpu_shares = 256

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:${var.port}/health"]
    interval     = "60s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }
}
