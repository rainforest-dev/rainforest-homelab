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

# The hall keeps no data of its own: its page is static, and /api/items gathers every
# collection's hall items server-side from the URLs below.
resource "docker_container" "library_hall" {
  image   = docker_image.this.image_id
  name    = "${var.project_name}-library-hall"
  restart = "always"

  memory      = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (can(regex("Gi", var.memory_limit)) ? 1024 : 1)
  memory_swap = -1

  ports {
    internal = 8087
    external = var.external_port
    ip       = var.bind_ip
  }

  env = concat(
    ["NODE_ENV=${var.node_env}"],
    [for name, url in var.collection_urls : "LIBRARY_${upper(name)}_URL=${url}" if url != ""],
  )

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
    value = "library-hall"
  }
}

# Terraform destroys the container before creating its new image; this dependent's destroy runs first, so the pull goes here.
resource "terraform_data" "pull_before_replace" {
  input = {
    image       = var.image
    docker_host = var.docker_host
  }
  triggers_replace = docker_container.library_hall.id

  provisioner "local-exec" {
    when    = destroy
    command = "docker pull \"$IMAGE\""
    environment = {
      IMAGE       = self.input.image
      DOCKER_HOST = self.input.docker_host
    }
  }
}
