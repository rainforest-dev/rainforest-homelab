locals {
  image_name = "${var.project_name}/vercel-board:local"
  module_dir = abspath(path.module)
  build_trigger = join(":", [
    var.board_user,
    filemd5("${path.module}/Dockerfile"),
    filemd5("${path.module}/entrypoint.mjs"),
    filemd5("${path.module}/package.json"),
    filemd5("${path.module}/package-lock.json"),
  ])
}

resource "null_resource" "build" {
  triggers = {
    build_trigger = local.build_trigger
  }

  provisioner "local-exec" {
    command = "docker build --build-arg BOARD_USER='${var.board_user}' -t '${local.image_name}' '${local.module_dir}'"
  }
}

resource "docker_image" "vercel_board" {
  name         = local.image_name
  keep_locally = true

  depends_on = [null_resource.build]
}

resource "docker_volume" "data" {
  name = "${var.project_name}-vercel-board-data"

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "service"
    value = "vercel-board"
  }
  labels {
    label = "environment"
    value = var.environment
  }
}

resource "docker_container" "vercel_board" {
  image   = docker_image.vercel_board.name
  name    = "${var.project_name}-vercel-board"
  restart = "always"

  memory      = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (can(regex("Gi", var.memory_limit)) ? 1024 : 1)
  memory_swap = -1

  ports {
    internal = 4101
    external = var.external_port
    ip       = "127.0.0.1"
  }

  env = [
    "BOARD_PORT=${var.external_port}",
    "BOARD_ALLOW_HOSTS=${join(",", var.allow_hosts)}",
  ]

  volumes {
    container_path = "/data"
    volume_name    = docker_volume.data.name
  }

  volumes {
    container_path = "/home/board/.config/board/local"
    host_path      = var.token_dir
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "service"
    value = "vercel-board"
  }
  labels {
    label = "environment"
    value = var.environment
  }

  lifecycle {
    replace_triggered_by = [null_resource.build]
  }

  depends_on = [docker_image.vercel_board]
}
