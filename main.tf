resource "kubernetes_namespace" "homelab" {
  metadata {
    name = "homelab"
  }
}
resource "kubernetes_namespace" "traefik" {
  metadata {
    name = "traefik"
  }
}

# Disabled due to connection issues - use local storage for now
# module "nfs-persistence" {
#   source = "./modules/nfs-persistence"
#   name   = "${var.project_name}-nfs"
# }

module "traefik" {
  source = "./modules/traefik"
  count  = var.enable_traefik ? 1 : 0

  project_name       = var.project_name
  environment        = var.environment
  domain_suffix      = var.domain_suffix
  enable_cloudflare  = var.enable_cloudflare
  cloudflare_api_key = var.cloudflare_api_key
  cloudflare_email   = var.cloudflare_email
  cpu_limit          = var.default_cpu_limit
  memory_limit       = var.default_memory_limit
  chart_repository   = "https://traefik.github.io/charts"
}

# Teleport removed as requested
# module "teleport" {
#   source = "./modules/teleport"
#
#   project_name       = var.project_name
#   environment        = var.environment
#   cpu_limit          = var.default_cpu_limit
#   memory_limit       = var.default_memory_limit
#   enable_persistence = var.enable_persistence
#   storage_size       = var.default_storage_size
#   chart_repository   = "https://charts.releases.teleport.dev"
# }

module "open-webui" {
  source = "./modules/open-webui"

  project_name       = var.project_name
  environment        = var.environment
  cpu_limit          = var.default_cpu_limit
  memory_limit       = var.default_memory_limit
  enable_persistence = var.enable_persistence
  storage_size       = var.default_storage_size
  ollama_enabled     = false
  chart_repository   = "https://helm.openwebui.com/"
}

module "flowise" {
  source = "./modules/flowise"

  project_name       = var.project_name
  environment        = var.environment
  cpu_limit          = var.default_cpu_limit
  memory_limit       = var.default_memory_limit
  enable_persistence = var.enable_persistence
  storage_size       = var.default_storage_size
  chart_repository   = "https://cowboysysop.github.io/charts"
}

module "postgresql" {
  source = "./modules/postgresql"
  count  = var.enable_postgresql ? 1 : 0

  project_name       = var.project_name
  environment        = var.environment
  enable_persistence = var.enable_persistence
  storage_size       = var.default_storage_size
  cpu_limit          = var.default_cpu_limit
  memory_limit       = var.default_memory_limit
}

module "openspeedtest" {
  source = "./modules/openspeedtest"

  project_name       = var.project_name
  environment        = var.environment
  cpu_limit          = var.default_cpu_limit
  memory_limit       = var.default_memory_limit
  enable_persistence = var.enable_persistence
  storage_size       = var.default_storage_size
}

module "calibre-web" {
  source = "./modules/calibre-web"

  project_name       = var.project_name
  environment        = var.environment
  enable_persistence = var.enable_persistence
  storage_size       = var.default_storage_size
  cpu_limit          = var.default_cpu_limit
  memory_limit       = var.default_memory_limit
}

module "n8n" {
  source = "./modules/n8n"

  project_name       = var.project_name
  environment        = var.environment
  cpu_limit          = var.default_cpu_limit
  memory_limit       = var.default_memory_limit
  enable_persistence = var.enable_persistence
  storage_size       = var.default_storage_size
  chart_repository   = "oci://8gears.container-registry.com/library/"
}

resource "docker_container" "dockerproxy" {
  image   = "ghcr.io/tecnativa/docker-socket-proxy:latest"
  name    = "dockerproxy"
  restart = "unless-stopped"
  env     = ["CONTAINERS=1", "SERVICES=1", "TASKS=1", "POST=0"]
  ports {
    internal = 2375
    external = 2375
  }
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }
}
