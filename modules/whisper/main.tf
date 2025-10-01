# Volume for model cache
module "whisper_models_volume" {
  source = "../volume-management"

  project_name         = var.project_name
  service_name         = "whisper"
  volume_name          = "models"
  environment          = var.environment
  volume_type          = "data"
  use_external_storage = var.use_external_storage
}

# Build Docker image from local Dockerfile
resource "docker_image" "whisper" {
  name = "${var.project_name}/whisper:${var.image_tag}"

  build {
    context    = path.module
    dockerfile = "Dockerfile"
    tag        = ["${var.project_name}/whisper:${var.image_tag}"]
    label = {
      project = var.project_name
      service = "whisper"
    }
  }

  # Force rebuild when files change
  triggers = {
    dockerfile_hash = filemd5("${path.module}/Dockerfile")
    main_py_hash    = filemd5("${path.module}/app/main.py")
    pyproject_hash  = filemd5("${path.module}/app/pyproject.toml")
  }
}

# Whisper Docker container
resource "docker_container" "whisper" {
  image   = docker_image.whisper.name
  name    = "${var.project_name}-whisper"
  restart = "unless-stopped"

  # Port mapping
  ports {
    internal = 8000
    external = var.external_port
  }

  # Environment variables
  env = [
    "WHISPER_MODEL=${var.model_size}",
    "CUDA_AVAILABLE=${var.enable_gpu ? "true" : "false"}"
  ]

  # Model cache volume
  volumes {
    container_path = "/models"
    volume_name    = module.whisper_models_volume.volume_name
  }

  # GPU support (if enabled and available)
  gpus = var.enable_gpu ? "all" : null

  # Labels for organization
  labels {
    label = "project"
    value = var.project_name
  }

  labels {
    label = "service"
    value = "whisper"
  }

  labels {
    label = "environment"
    value = var.environment
  }

  # Wait for image to be ready
  depends_on = [docker_image.whisper]
}