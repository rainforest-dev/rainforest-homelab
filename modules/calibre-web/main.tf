# Create Docker volumes for Calibre Web
module "calibre_config_volume" {
  source = "../volume-management"

  project_name = var.project_name
  service_name = "calibre-web"
  volume_name  = "config"
  environment  = var.environment
  volume_type  = "config"
}

module "calibre_books_volume" {
  source = "../volume-management"

  project_name = var.project_name
  service_name = "calibre-web"
  volume_name  = "books"
  environment  = var.environment
  volume_type  = "data"
}

resource "docker_container" "calibre-web" {
  image   = "${var.image_name}:${var.image_tag}"
  name    = "${var.project_name}-calibre-web"
  restart = "unless-stopped"

  ports {
    internal = var.internal_port
    external = var.external_port
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}"
  ]

  volumes {
    container_path = "/config"
    volume_name    = module.calibre_config_volume.volume_name
  }

  volumes {
    container_path = "/books"
    volume_name    = module.calibre_books_volume.volume_name
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
    value = "calibre-web"
  }
}
