# Notebook DB, page images and search index, all under /data
resource "docker_volume" "data" {
  name = "${var.project_name}-personal-notebook-data"

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "service"
    value = "personal-notebook"
  }
  labels {
    label = "environment"
    value = var.environment
  }
}

locals {
  image_repository = regex("^(.*):[^:/]+$", var.image)[0]
  import_path      = "/calibre-app-data"
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

resource "docker_container" "personal_notebook" {
  image   = docker_image.this.image_id
  name    = "${var.project_name}-personal-notebook"
  restart = "always"

  memory      = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (can(regex("Gi", var.memory_limit)) ? 1024 : 1)
  memory_swap = -1

  ports {
    internal = 8080
    external = var.external_port
    ip       = var.bind_ip
  }

  env = concat(
    [
      "NODE_ENV=${var.node_env}",
      "NOTEBOOK_DATA_DIR=/data",
      "NOTEBOOK_MCP_SECRET=${var.mcp_secret}",
      "NOTEBOOK_INBOX_SECRET=${var.inbox_secret}",
      "NOTEBOOK_OLLAMA_URL=${var.ollama_url}",
    ],
    var.import_volume != "" ? ["NOTEBOOK_IMPORT_FROM=${local.import_path}"] : [],
    var.embed_model != "" ? ["NOTEBOOK_EMBED_MODEL=${var.embed_model}"] : [],
    var.ocr_model != "" ? ["NOTEBOOK_OCR_MODEL=${var.ocr_model}"] : [],
  )

  volumes {
    container_path = "/data"
    volume_name    = docker_volume.data.name
  }

  # personal-calibre's app-data volume, read-only. On a first start with an empty /data the app
  # copies the notebooks, page images and page index it finds there, then never reads it again.
  dynamic "volumes" {
    for_each = var.import_volume != "" ? [var.import_volume] : []
    content {
      container_path = local.import_path
      volume_name    = volumes.value
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
    value = "personal-notebook"
  }
}

# Terraform destroys the container before creating its new image; this dependent's destroy runs first, so the pull goes here.
resource "terraform_data" "pull_before_replace" {
  input = {
    image       = var.image
    docker_host = var.docker_host
  }
  triggers_replace = docker_container.personal_notebook.id

  provisioner "local-exec" {
    when    = destroy
    command = "docker pull \"$IMAGE\""
    environment = {
      IMAGE       = self.input.image
      DOCKER_HOST = self.input.docker_host
    }
  }
}
