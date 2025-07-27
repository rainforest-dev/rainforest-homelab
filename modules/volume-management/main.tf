resource "docker_volume" "volume" {
  name = "${var.project_name}-${var.service_name}-${var.volume_name}"

  labels {
    label = "project"
    value = var.project_name
  }

  labels {
    label = "service"
    value = var.service_name
  }

  labels {
    label = "environment"
    value = var.environment
  }

  labels {
    label = "volume_type"
    value = var.volume_type
  }

  driver_opts = var.driver_opts
}