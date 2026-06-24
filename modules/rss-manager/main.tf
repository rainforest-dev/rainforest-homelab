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

resource "docker_container" "rss_manager" {
  image   = var.image
  name    = "${var.project_name}-rss-manager"
  restart = "unless-stopped"

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

  # Obsidian vault registry folder — mounted read-only
  volumes {
    container_path = "/vault"
    host_path      = var.vault_registry_path
    read_only      = true
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
