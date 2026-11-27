# The partner-sync database (one SQLite file) under /data
resource "docker_volume" "data" {
  name = "${var.project_name}-pomodoro-data"

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "service"
    value = "pomodoro"
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

resource "docker_container" "pomodoro" {
  image   = docker_image.this.image_id
  name    = "${var.project_name}-pomodoro"
  restart = "always"

  memory      = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (can(regex("Gi", var.memory_limit)) ? 1024 : 1)
  memory_swap = -1

  ports {
    internal = 8790
    external = var.external_port
    ip       = var.bind_ip
  }

  env = concat(
    [
      "PUBLIC_ORIGIN=${var.public_origin}",
      "TRUST_PROXY=1",
      "DATA_DIR=/data",
    ],
    var.vapid_public_key != "" ? [
      "VAPID_PUBLIC_KEY=${var.vapid_public_key}",
      "VAPID_PRIVATE_KEY=${var.vapid_private_key}",
      "VAPID_SUBJECT=${var.vapid_subject}",
    ] : [],
  )

  volumes {
    container_path = "/data"
    volume_name    = docker_volume.data.name
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
    value = "pomodoro"
  }
}

# Terraform destroys the container before creating its new image; this dependent's destroy runs first, so the pull goes here.
resource "terraform_data" "pull_before_replace" {
  input = {
    image       = var.image
    docker_host = var.docker_host
  }
  triggers_replace = docker_container.pomodoro.id

  provisioner "local-exec" {
    when    = destroy
    command = "docker pull \"$IMAGE\""
    environment = {
      IMAGE       = self.input.image
      DOCKER_HOST = self.input.docker_host
    }
  }
}
