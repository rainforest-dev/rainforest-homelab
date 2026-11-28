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

# The image is private, and the provider pulls from ghcr anonymously (it cannot read the macOS
# keychain where `docker login` keeps the token). So the docker CLI pulls, and the container is
# pinned to the ID of the image it pulled. A new release: `docker pull` the tag, or apply with
# -replace=module.pomodoro.terraform_data.pull.
resource "terraform_data" "pull" {
  triggers_replace = [var.image]

  provisioner "local-exec" {
    command = "docker pull \"$IMAGE\""
    environment = {
      IMAGE       = var.image
      DOCKER_HOST = var.docker_host
    }
  }
}

data "docker_image" "this" {
  name       = var.image
  depends_on = [terraform_data.pull]
}

resource "docker_container" "pomodoro" {
  image   = data.docker_image.this.id
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
