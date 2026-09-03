resource "docker_image" "alloy" {
  name         = "grafana/alloy:${var.image_version}"
  keep_locally = true
}

resource "docker_container" "alloy" {
  name  = "${var.project_name}-alloy"
  image = docker_image.alloy.image_id

  restart = "always"

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

  volumes {
    host_path      = var.kubeconfig_path
    container_path = "/etc/alloy/kubeconfig"
    read_only      = true
  }

  ports {
    internal = 12345
    external = 12345
    protocol = "tcp"
  }

  # OTLP intake for agent CLIs (Claude Code, Codex). Bound on all interfaces so
  # the other machine can publish here too, not just processes on this host.
  ports {
    internal = 4317
    external = 4317
    protocol = "tcp"
  }

  ports {
    internal = 4318
    external = 4318
    protocol = "tcp"
  }

  # 192 MB left no headroom: the container sat at ~173 MB (90%) with only the
  # scrape and docker-logs pipelines loaded, so adding an OTLP receiver and batch
  # processor to that ceiling would OOM-restart under load -- and an OOM loop
  # looks like flaky telemetry, which sends you debugging the wrong component.
  memory     = 384
  cpu_shares = 512

  lifecycle {
    ignore_changes = [memory_swap]
  }

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD-SHELL", "bash -c 'echo > /dev/tcp/127.0.0.1/12345' 2>/dev/null && echo healthy"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }
}
