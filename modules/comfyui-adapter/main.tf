resource "docker_image" "comfyui_adapter" {
  name = "${var.project_name}/comfyui-adapter:${var.image_tag}"

  build {
    context    = path.module
    dockerfile = "Dockerfile"
    tag        = ["${var.project_name}/comfyui-adapter:${var.image_tag}"]
    label = {
      project = var.project_name
      service = "comfyui-adapter"
    }
  }

  triggers = {
    dockerfile_hash = filemd5("${path.module}/Dockerfile")
    main_py_hash    = filemd5("${path.module}/app/main.py")
    workflow_hash   = filemd5("${path.module}/app/workflow.json")
    pyproject_hash  = filemd5("${path.module}/app/pyproject.toml")
  }
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
