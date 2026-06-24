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

# Build Docker image via local-exec — the kreuzwerker/docker provider's legacy
# build API corrupts the gzip build context on macOS Docker Desktop (unpigz CRC32 mismatch).
resource "null_resource" "whisper_build" {
  triggers = {
    dockerfile_hash = filemd5("${path.module}/Dockerfile")
    main_py_hash    = filemd5("${path.module}/app/main.py")
    pyproject_hash  = filemd5("${path.module}/app/pyproject.toml")
  }

  provisioner "local-exec" {
    command = "docker build -t ${var.project_name}/whisper:${var.image_tag} ${path.module}"
  }
}

resource "docker_image" "whisper" {
  name         = "${var.project_name}/whisper:${var.image_tag}"
  keep_locally = true

  depends_on = [null_resource.whisper_build]
}

# Whisper Docker container
resource "docker_container" "whisper" {
  image   = docker_image.whisper.name
  name    = "${var.project_name}-whisper"
  restart = "unless-stopped"

  memory = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (
    can(regex("Gi", var.memory_limit)) ? 1024 * 1024 * 1024 :
    can(regex("Mi", var.memory_limit)) ? 1024 * 1024 : 1
  )
  memory_swap = -1

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

  depends_on = [null_resource.whisper_build]
}