resource "docker_image" "alloy" {
  name         = "grafana/alloy:${var.image_version}"
  keep_locally = true
}

resource "docker_container" "alloy" {
  name  = "${var.project_name}-alloy"
  image = docker_image.alloy.image_id

  restart = "unless-stopped"

  command = [
    "run",
    "--server.http.listen-addr=0.0.0.0:12345",
    "--storage.path=/var/lib/alloy",
    "/etc/alloy/alloy.river",
  ]

  env = [
    "PROMETHEUS_REMOTE_WRITE_URL=${var.prometheus_remote_write_url}",
    "LOKI_PUSH_URL=${var.loki_push_url}",
  ]

  volumes {
    host_path      = abspath("${path.module}/alloy.river")
    container_path = "/etc/alloy/alloy.river"
    read_only      = true
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  ports {
    internal = 12345
    external = 12345
    protocol = "tcp"
  }

  memory = 128

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "bash", "-c", "echo > /dev/tcp/localhost/12345"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }
}
