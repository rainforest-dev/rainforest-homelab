# Persistent volume for the app DB (delivery tracking)
resource "docker_volume" "app_data" {
  name = "${var.project_name}-personal-calibre-app-data"

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "service"
    value = "personal-calibre"
  }
  labels {
    label = "environment"
    value = var.environment
  }
}

resource "docker_container" "personal_calibre" {
  image   = var.image
  name    = "${var.project_name}-personal-calibre"
  restart = "unless-stopped"

  ports {
    internal = 8080
    external = var.external_port
  }

  env = [
    "NODE_ENV=${var.node_env}",
    # Read-only Calibre library, mounted at /calibre-library inside the container
    "CALIBRE_LIBRARY_PATH=/calibre-library",
    # App DB lives in the persistent volume, separate from the library
    "CALIBRE_APP_DB_PATH=/app-data/personal-calibre-app.db",
  ]

  # Calibre library — bind-mounted read-only so the app never modifies it
  volumes {
    container_path = "/calibre-library"
    host_path      = var.calibre_library_path
    read_only      = true
  }

  # Persistent app DB volume — writable, survives container restarts and updates
  volumes {
    container_path = "/app-data"
    volume_name    = docker_volume.app_data.name
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
    value = "personal-calibre"
  }
}
