# Simplified volume management with external disk support
locals {
  external_storage_base = "/Volumes/Samsung T7 Touch/homelab-data"
  volume_path = var.use_external_storage ? "${local.external_storage_base}/${var.service_name}" : null
  
  # Driver options based on storage type
  driver_options = var.use_external_storage ? {
    type   = "none"
    o      = "bind"
    device = local.volume_path
  } : var.driver_opts
}

# Create directory on external storage if needed
resource "null_resource" "external_directory" {
  count = var.use_external_storage ? 1 : 0
  
  provisioner "local-exec" {
    command = "mkdir -p '${local.volume_path}' && chmod 755 '${local.volume_path}'"
  }
  
  triggers = {
    path = local.volume_path
  }
}

# Docker volume (works for both internal and external storage)
resource "docker_volume" "volume" {
  name   = "${var.project_name}-${var.service_name}-${var.volume_name}"
  driver = "local"
  
  driver_opts = local.driver_options

  labels {
    label = "project"
    value = var.project_name
  }

  labels {
    label = "service"
    value = var.service_name
  }

  labels {
    label = "environment"
    value = var.environment
  }

  labels {
    label = "volume_type"
    value = var.volume_type
  }

  labels {
    label = "storage_type"
    value = var.use_external_storage ? "external" : "docker"
  }

  depends_on = [null_resource.external_directory]
}