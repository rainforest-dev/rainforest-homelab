resource "kubernetes_namespace" "homelab" {
  metadata {
    name = "homelab"
  }
}
# Traefik removed - using Cloudflare Tunnel for ingress
# Legacy namespace and module removed



# PostgreSQL Stack with pgAdmin and automated backups
module "postgresql" {
  source = "./modules/postgresql"
  count  = var.enable_postgresql ? 1 : 0

  project_name = var.project_name
  environment  = var.environment

  # PostgreSQL configuration
  postgres_external_port = 5432
  postgres_memory_limit  = 512
  postgres_cpu_limit     = 1.0

  # pgAdmin configuration  
  pgadmin_external_port = 5050
  pgadmin_email         = "contact@rainforest.tools"

  # Services will self-register their databases

  # Backup configuration
  backup_enabled        = true
  backup_schedule       = "0 2 * * *"  # Daily at 2 AM
  backup_retention_days = 30
}

module "docker_mcp_gateway" {
  source = "./modules/docker-mcp-gateway"
  count  = var.enable_docker_mcp_gateway ? 1 : 0

  project_name = var.project_name
  environment  = var.environment

  # Resource configuration
  memory_limit = var.default_memory_limit

  # External access configuration
  enable_cloudflare_tunnel = var.enable_cloudflare_tunnel
  tunnel_hostname          = "docker-mcp"
  domain_suffix            = var.domain_suffix
  docker_host_address      = "host.docker.internal" # Configurable for platform compatibility

  # Logging configuration
  log_level = "info"
}

# OAuth Worker for Docker MCP Gateway
module "oauth_worker" {
  source = "./modules/oauth-worker"
  count  = var.enable_docker_mcp_gateway && var.oauth_client_id != "" ? 1 : 0

  project_name          = var.project_name
  environment           = var.environment
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.enable_cloudflare_tunnel ? module.cloudflare_tunnel[0].zone_id : ""
  cloudflare_team_name  = var.cloudflare_team_name
  domain_suffix         = var.domain_suffix
  oauth_client_id       = var.oauth_client_id
  oauth_client_secret   = var.oauth_client_secret

  depends_on = [module.docker_mcp_gateway]
}

# Open WebUI Database Self-Registration
module "open_webui_database" {
  count = length(module.postgresql) > 0 ? 1 : 0
  
  source = "./modules/database-init"
  
  service_name            = "open-webui"
  database_name           = "open_webui_db"
  postgres_container_name = module.postgresql[0].postgres_container_name
  postgres_user           = module.postgresql[0].postgres_user
  postgres_password       = module.postgresql[0].postgres_password
  
  # Create service-specific user for better security
  service_user     = "open_webui_user"
  service_password = "secure_open_webui_password_2024"
  
  # Custom initialization SQL for Open WebUI
  init_sql = <<-SQL
    -- Create extensions for Open WebUI
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    -- Vector extension for embeddings (if available)
    CREATE EXTENSION IF NOT EXISTS "vector" SCHEMA public;
    
    -- Grant permissions for vector operations
    GRANT ALL ON SCHEMA public TO open_webui_user;
    
    -- Comment on database
    COMMENT ON DATABASE open_webui_db IS 'Open WebUI AI interface database';
  SQL
  
  force_recreate = "2"  # Updated to include schema permissions
  
  depends_on = [module.postgresql]
}

module "open-webui" {
  source = "./modules/open-webui"

  project_name       = var.project_name
  environment        = var.environment
  cpu_limit          = "2"      # Generous CPU for smooth web search and AI processing  
  memory_limit       = "4Gi"    # High memory to prevent OOM during web search operations
  enable_persistence = var.enable_persistence
  storage_size       = var.default_storage_size
  ollama_enabled     = false
  ollama_base_url    = var.ollama_base_url
  chart_repository   = "https://helm.openwebui.com/"
  chart_version      = "8.7.0" # Updated to v0.6.31 with native MCP support
  
  # Switch to Docker deployment with PostgreSQL database
  deployment_type  = "docker"
  database_url     = length(module.open_webui_database) > 0 ? "postgresql://${module.open_webui_database[0].database_user}:secure_open_webui_password_2024@${module.postgresql[0].postgres_host}:5432/${module.open_webui_database[0].database_name}" : ""
  
  depends_on = [module.open_webui_database]
}

# Flowise Database Self-Registration
module "flowise_database" {
  count = length(module.postgresql) > 0 ? 1 : 0
  
  source = "./modules/database-init"
  
  service_name            = "flowise"
  database_name           = "flowise_db"
  postgres_container_name = module.postgresql[0].postgres_container_name
  postgres_user           = module.postgresql[0].postgres_user
  postgres_password       = module.postgresql[0].postgres_password
  
  # Create service-specific user for better security
  service_user     = "flowise_user"
  service_password = "secure_flowise_password_2024"
  
  # Custom initialization SQL for Flowise
  init_sql = <<-SQL
    -- Create extensions for Flowise
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
    -- Grant permissions for application operations
    GRANT ALL ON SCHEMA public TO flowise_user;
    
    -- Comment on database
    COMMENT ON DATABASE flowise_db IS 'Flowise AI workflow automation database';
  SQL
  
  force_recreate = "1"  # Initial creation
  
  depends_on = [module.postgresql]
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
  chart_version      = "1.0.15"  # Updated to n8n v1.112.0
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
  service_token_ids     = var.service_token_ids
  services              = local.services

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
