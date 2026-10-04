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

locals {
  image_repository = regex("^(.*):[^:/]+$", var.image)[0]
}

data "docker_registry_image" "this" {
  name = var.image
}

resource "docker_image" "this" {
  name         = "${local.image_repository}@${data.docker_registry_image.this.sha256_digest}"
  keep_locally = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_container" "personal_calibre" {
  image   = docker_image.this.image_id
  name    = "${var.project_name}-personal-calibre"
  restart = "always"

  memory      = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (can(regex("Gi", var.memory_limit)) ? 1024 : 1)
  memory_swap = -1

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

# Terraform destroys the container before creating its new image; this dependent's destroy runs first, so the pull goes here.
resource "terraform_data" "pull_before_replace" {
  input = {
    image       = var.image
    docker_host = var.docker_host
  }
  triggers_replace = docker_container.personal_calibre.id

  provisioner "local-exec" {
    when    = destroy
    command = "docker pull \"$IMAGE\""
    environment = {
      IMAGE       = self.input.image
      DOCKER_HOST = self.input.docker_host
    }
  }
}
