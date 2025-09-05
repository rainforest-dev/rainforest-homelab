resource "kubernetes_namespace" "homelab" {
  metadata {
    name = "homelab"
  }
}
# Traefik removed - using Cloudflare Tunnel for ingress
# Legacy namespace and module removed


module "mcpo" {
  source = "./modules/mcpo"

  project_name = var.project_name
  environment  = var.environment
}

module "docker_mcp_gateway" {
  source = "./modules/docker-mcp-gateway"
  count  = var.enable_docker_mcp_gateway ? 1 : 0

  project_name = var.project_name
  environment  = var.environment
  namespace    = "homelab"
  
  # Resource configuration
  cpu_limit    = var.default_cpu_limit
  memory_limit = var.default_memory_limit
  
  # External access configuration
  enable_cloudflare_tunnel = var.enable_cloudflare_tunnel
  tunnel_hostname         = "docker-mcp"
  domain_suffix          = var.domain_suffix
  
  # Security configuration
  enable_docker_socket  = true
  enable_network_policy = false  # Can be enabled in production
  log_level            = "info"
  
  depends_on = [kubernetes_namespace.homelab]
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
  ollama_base_url    = var.ollama_base_url
  chart_repository   = "https://helm.openwebui.com/"
  chart_version      = "7.7.0"
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
  chart_version      = "6.0.0"
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

module "minio" {
  source = "./modules/minio"
  count  = var.enable_minio ? 1 : 0

  project_name       = var.project_name
  environment        = var.environment
  enable_persistence = var.enable_persistence
  storage_size       = var.minio_storage_size
  cpu_limit          = var.default_cpu_limit
  memory_limit       = var.default_memory_limit
  chart_repository   = "https://charts.min.io/"
  chart_version      = "5.2.0"
}

# OpenSpeedTest moved to Raspberry Pi (external hosting)
# Module kept in /modules for reference if needed

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
  chart_version      = "1.0.13"
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

# CoreDNS removed - using Cloudflare Tunnel for external DNS
# Legacy module kept in /modules for reference

module "cloudflare_tunnel" {
  source = "./modules/cloudflare-tunnel"
  count  = var.enable_cloudflare_tunnel ? 1 : 0

  project_name          = var.project_name
  domain_suffix         = var.domain_suffix
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_api_token  = var.cloudflare_api_token
  kubernetes_namespace  = "homelab"
  allowed_email_domains = var.allowed_email_domains
  allowed_emails        = var.allowed_emails

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
