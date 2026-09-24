resource "docker_volume" "app_data" {
  name = "${var.project_name}-rss-manager-app-data"

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "service"
    value = "rss-manager"
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
}

resource "docker_container" "rss_manager" {
  image   = docker_image.this.image_id
  name    = "${var.project_name}-rss-manager"
  restart = "always"

  memory = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (
    can(regex("Gi", var.memory_limit)) ? 1024 * 1024 * 1024 :
    can(regex("Mi", var.memory_limit)) ? 1024 * 1024 : 1
  )
  memory_swap = -1

  ports {
    internal = 3002
    external = var.external_port
  }

  env = [
    "NODE_ENV=${var.node_env}",
    "VAULT_PATH=/vault",
  ]

  # Obsidian vault registry folder. Writable: the app's Activate / Retire /
  # Decline buttons edit the registry markdown in place, and a read-only mount
  # failed every one of them. The mount is the vault's registry folder alone, so
  # the container reaches nothing else, and the service sits behind the access
  # gate.
  volumes {
    container_path = "/vault"
    host_path      = var.vault_registry_path
    read_only      = false
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
    value = "rss-manager"
  }
}
