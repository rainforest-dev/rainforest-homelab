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


module "traefik" {
  source = "./modules/traefik"
  count  = var.enable_traefik ? 1 : 0

  project_name       = var.project_name
  environment        = var.environment
  domain_suffix      = var.domain_suffix
# Cloudflare integration removed - using Tailscale + CoreDNS instead
  cpu_limit          = var.default_cpu_limit
  memory_limit       = var.default_memory_limit
  chart_repository   = "https://traefik.github.io/charts"
}


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

module "homepage" {
  source = "./modules/homepage"

  project_name       = var.project_name
  environment        = var.environment
  cpu_limit          = var.default_cpu_limit
  memory_limit       = var.default_memory_limit
  enable_persistence = var.enable_persistence
  storage_size       = var.default_storage_size
  chart_repository   = "https://jameswynn.github.io/helm-charts"
  domain_suffix      = var.domain_suffix
}

module "metrics_server" {
  source = "./modules/metrics-server"

  project_name = var.project_name
  environment  = var.environment
  cpu_limit    = var.default_cpu_limit
  memory_limit = var.default_memory_limit
}

module "coredns" {
  source = "./modules/coredns"
  count  = var.enable_coredns && !var.enable_cloudflare_tunnel ? 1 : 0

  project_name  = var.project_name
  environment   = var.environment
  namespace     = "homelab"
  tailscale_ip  = var.tailscale_ip
  cpu_limit     = var.default_cpu_limit
  memory_limit  = var.default_memory_limit
}

module "cloudflare_tunnel" {
  source = "./modules/cloudflare-tunnel"
  count  = var.enable_cloudflare_tunnel ? 1 : 0

  project_name           = var.project_name
  domain_suffix          = var.domain_suffix
  cloudflare_account_id  = var.cloudflare_account_id
  cloudflare_api_token   = var.cloudflare_api_token
  kubernetes_namespace   = "homelab"
  allowed_email_domains  = var.allowed_email_domains
  allowed_emails         = var.allowed_emails

  depends_on = [kubernetes_namespace.homelab]
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
