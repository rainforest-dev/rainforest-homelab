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

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_container" "rss_manager" {
  image   = docker_image.this.image_id
  name    = "${var.project_name}-rss-manager"
  restart = "always"

  memory      = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (can(regex("Gi", var.memory_limit)) ? 1024 : 1)
  memory_swap = -1

  ports {
    internal = 3002
    external = var.external_port
    ip       = var.bind_ip
  }

  env = [
    "NODE_ENV=${var.node_env}",
    "VAULT_PATH=/vault",
    "KB_WIKI_PATH=/kb/wiki",
    "KB_READWISE_PATH=/kb/readwise",
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

  # The knowledge base at /kb: the wiki's pages and Readwise, each read-only on its own. The
  # vault's notes/ is never mounted, because a bind mount cannot leave out notes/personal/.
  dynamic "volumes" {
    for_each = { for path, host in {
      "/kb/wiki"     = var.kb_wiki_pages_path
      "/kb/readwise" = var.kb_readwise_path
    } : path => host if host != "" }
    content {
      container_path = volumes.key
      host_path      = volumes.value
      read_only      = true
    }
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

# Terraform destroys the container before creating its new image; this dependent's destroy runs first, so the pull goes here.
resource "terraform_data" "pull_before_replace" {
  input = {
    image       = var.image
    docker_host = var.docker_host
  }
  triggers_replace = docker_container.rss_manager.id

  provisioner "local-exec" {
    when    = destroy
    command = "docker pull \"$IMAGE\""
    environment = {
      IMAGE       = self.input.image
      DOCKER_HOST = self.input.docker_host
    }
  }
}
