locals {
  image_name   = "${var.project_name}/comfyui-adapter:${var.image_tag}"
  module_dir   = abspath(path.module)
  build_trigger = join(":", [
    filemd5("${path.module}/Dockerfile"),
    filemd5("${path.module}/app/main.py"),
    filemd5("${path.module}/app/workflow.json"),
    filemd5("${path.module}/app/pyproject.toml"),
  ])
}

# Build the image via docker CLI (more reliable than the provider's built-in build)
resource "null_resource" "build" {
  triggers = {
    build_trigger = local.build_trigger
  }

  provisioner "local-exec" {
    command = "docker build -t '${local.image_name}' '${local.module_dir}'"
  }
}

# Reference the pre-built image by name
resource "docker_image" "comfyui_adapter" {
  name         = local.image_name
  keep_locally = true

  depends_on = [null_resource.build]
}

resource "docker_container" "comfyui_adapter" {
  image   = docker_image.comfyui_adapter.name
  name    = "${var.project_name}-comfyui-adapter"
  restart = "unless-stopped"

  ports {
    internal = 7860
    external = var.external_port
  }

  env = compact([
    "COMFYUI_HOST=${var.comfyui_host}",
    var.api_key != "" ? "API_KEY=${var.api_key}" : "",
  ])

  labels {
    label = "project"
    value = var.project_name
  }

  labels {
    label = "service"
    value = "comfyui-adapter"
  }

  labels {
    label = "environment"
    value = var.environment
  }

  depends_on = [docker_image.comfyui_adapter]
}
