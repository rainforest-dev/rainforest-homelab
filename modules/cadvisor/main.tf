resource "docker_image" "cadvisor" {
  name         = "gcr.io/cadvisor/cadvisor:${var.image_version}"
  keep_locally = true
}

resource "docker_container" "cadvisor" {
  name  = "${var.project_name}-cadvisor"
  image = docker_image.cadvisor.image_id

  restart = "unless-stopped"

  # privileged is required so cAdvisor can read cgroup v2 inside Docker Desktop's Linux VM.
  # Without it, only the root "/" cgroup is visible and per-container metrics are absent.
  privileged = true

  volumes {
    host_path      = "/sys"
    container_path = "/sys"
    read_only      = true
  }

  volumes {
    host_path      = "/var/lib/docker"
    container_path = "/var/lib/docker"
    read_only      = true
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  ports {
    internal = 8080
    external = var.port
    protocol = "tcp"
  }

  command = [
    "--housekeeping_interval=10s",
    "--docker_only=true",
    "--disable_metrics=advtcp,cpu_topology,cpuset,hugetlb,memory_numa,percpu,referenced_memory,resctrl,sched,tcp,udp",
  ]

  memory     = 256
  cpu_shares = 256

  lifecycle {
    ignore_changes = [memory_swap]
  }

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://127.0.0.1:8080/healthz"]
    interval     = "30s"
    timeout      = "5s"
    retries      = 3
    start_period = "15s"
  }
}
