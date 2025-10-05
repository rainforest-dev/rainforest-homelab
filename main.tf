# Random passwords for database services
# Open WebUI password - DISABLED (using SQLite instead of PostgreSQL)
# resource "random_password" "open_webui_password" {
#   length  = 24
#   special = true
# }

resource "random_password" "flowise_password" {
  length  = 24
  special = true
}

resource "random_password" "n8n_password" {
  length  = 24
  special = true
}

resource "kubernetes_namespace" "homelab" {
  metadata {
    name = "homelab"
  }
}
# Traefik removed - using Cloudflare Tunnel for ingress
# Legacy namespace and module removed



# PostgreSQL Helm Chart with External Storage
module "postgresql" {
  source = "./modules/postgresql"

  project_name = var.project_name
  environment  = var.environment
  namespace    = "homelab"

  # PostgreSQL configuration
  postgres_database     = "homelab"
  cpu_limit             = 1000
  memory_limit          = 512
  storage_size          = "20Gi"
  external_storage_path = var.external_storage_path

  # pgAdmin configuration
  enable_pgadmin = true
  pgadmin_email  = "contact@rainforest.tools"

  # Monitoring
  enable_metrics = true
}

module "docker_mcp_gateway" {
  source = "./modules/docker-mcp-gateway"

  project_name = var.project_name
  environment  = var.environment

  # Resource configuration
  memory_limit = var.default_memory_limit

  # External access configuration
  enable_cloudflare_tunnel = true
  tunnel_hostname          = "docker-mcp"
  domain_suffix            = var.domain_suffix
  docker_host_address      = "host.docker.internal" # Configurable for platform compatibility

  # Logging configuration
  log_level = "info"
}

# OAuth Worker for Docker MCP Gateway
module "oauth_worker" {
  source = "./modules/oauth-worker"
  count  = var.oauth_client_id != "" ? 1 : 0

  project_name          = var.project_name
  environment           = var.environment
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = module.cloudflare_tunnel.zone_id
  cloudflare_team_name  = var.cloudflare_team_name
  domain_suffix         = var.domain_suffix
  oauth_client_id       = var.oauth_client_id
  oauth_client_secret   = var.oauth_client_secret

  depends_on = [module.docker_mcp_gateway]
}

# Open WebUI Database - DISABLED (using SQLite instead of PostgreSQL)
# module "open_webui_database" {
#   count = 0  # Disabled - Open WebUI now uses SQLite
#   
#   source = "./modules/database-init"
#   
#   service_name      = "open-webui"
#   database_name     = "open_webui_db"
#   postgres_host     = module.postgresql[0].postgresql_host
#   postgres_user     = module.postgresql[0].postgresql_username
#   postgres_password = module.postgresql[0].postgres_password
#   namespace         = "homelab"
#   
#   # Create service-specific user for better security
#   service_user     = "open_webui_user"
#   service_password = random_password.open_webui_password.result
#   
#   # Custom initialization SQL for Open WebUI
#   init_sql = <<-SQL
#     -- Create extensions for Open WebUI
#     CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
#     -- Vector extension for embeddings (if available)
#     CREATE EXTENSION IF NOT EXISTS "vector" SCHEMA public;
#     
#     -- Grant permissions for vector operations
#     GRANT ALL ON SCHEMA public TO open_webui_user;
#     
#     -- Comment on database
#     COMMENT ON DATABASE open_webui_db IS 'Open WebUI AI interface database';
#   SQL
#   
#   force_recreate = "3"  # Clean database recreation after dropping DB
#   
#   depends_on = [module.postgresql]
# }

module "open-webui" {
  source = "./modules/open-webui"

  project_name       = var.project_name
  environment        = var.environment
  cpu_limit          = "2"   # Generous CPU for smooth web search and AI processing
  memory_limit       = "4Gi" # High memory to prevent OOM during web search operations
  enable_persistence = var.enable_persistence
  storage_size       = var.default_storage_size
  ollama_enabled     = false
  ollama_base_url    = var.ollama_base_url
  chart_repository   = "https://helm.openwebui.com/"
  chart_version      = "8.7.0" # Latest version with clean database

  # Switch to Helm deployment with PostgreSQL database
  deployment_type = "helm"
  database_url    = "" # Use SQLite (default) instead of PostgreSQL to avoid migration bugs

  # External storage configuration
  use_external_storage  = true
  external_storage_path = var.external_storage_path

  # Whisper STT integration
  whisper_stt_url = "https://whisper.${var.domain_suffix}"
  domain_suffix   = var.domain_suffix

  # No longer depends on PostgreSQL database - using SQLite
}

# Flowise Database Self-Registration
module "flowise_database" {
  source = "./modules/database-init"

  service_name         = "flowise"
  database_name        = "flowise_db"
  postgres_host        = module.postgresql.postgresql_host
  postgres_user        = module.postgresql.postgresql_username
  postgres_secret_name = module.postgresql.postgresql_secret_name
  postgres_secret_key  = "postgres-password"
  namespace            = "homelab"

  # Create service-specific user for better security
  service_user     = "flowise_user"
  service_password = random_password.flowise_password.result

  # Custom initialization SQL for Flowise
  init_sql = <<-SQL
    -- Create extensions for Flowise
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
    -- Grant permissions for application operations
    GRANT ALL ON SCHEMA public TO flowise_user;
    
    -- Comment on database
    COMMENT ON DATABASE flowise_db IS 'Flowise AI workflow automation database';
  SQL

  force_recreate = "2" # Recreate after PostgreSQL password fix

  depends_on = [module.postgresql]
}

# n8n Database Self-Registration
module "n8n_database" {
  source = "./modules/database-init"

  service_name         = "n8n"
  database_name        = "n8n_db"
  postgres_host        = module.postgresql.postgresql_host
  postgres_user        = module.postgresql.postgresql_username
  postgres_secret_name = module.postgresql.postgresql_secret_name
  postgres_secret_key  = "postgres-password"
  namespace            = "homelab"

  # Create service-specific user for better security
  service_user     = "n8n_user"
  service_password = random_password.n8n_password.result

  # Custom initialization SQL for n8n
  init_sql = <<-SQL
    -- Create extensions for n8n
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
    -- Grant permissions for application operations
    GRANT ALL ON SCHEMA public TO n8n_user;
    
    -- Comment on database
    COMMENT ON DATABASE n8n_db IS 'n8n workflow automation database';
  SQL

  force_recreate = "1" # Initial creation

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

  # External storage configuration
  use_external_storage  = true
  external_storage_path = var.external_storage_path

  # PostgreSQL configuration
  database_type        = "postgres"
  database_host        = module.postgresql.postgresql_host
  database_port        = "5432"
  database_name        = "flowise_db"
  database_user        = "postgres"
  database_secret_name = module.postgresql.postgresql_secret_name
  database_secret_key  = "postgres-password"

  depends_on = [module.flowise_database]
}


module "minio" {
  source = "./modules/minio"

  project_name         = var.project_name
  environment          = var.environment
  enable_persistence   = var.enable_persistence
  storage_size         = var.minio_storage_size
  cpu_limit            = var.default_cpu_limit
  memory_limit         = var.default_memory_limit
  chart_repository     = "https://charts.min.io/"
  chart_version        = "5.2.0"
  use_external_storage = true # Enable external storage on Samsung T7
}

# OpenSpeedTest moved to Raspberry Pi (external hosting)
# Module kept in /modules for reference if needed

module "calibre-web" {
  source = "./modules/calibre-web"

  project_name         = var.project_name
  environment          = var.environment
  enable_persistence   = var.enable_persistence
  storage_size         = var.default_storage_size
  cpu_limit            = var.default_cpu_limit
  memory_limit         = var.default_memory_limit
  use_external_storage = true
}

module "n8n" {
  source = "./modules/n8n"

  project_name          = var.project_name
  environment           = var.environment
  namespace             = "homelab"
  external_storage_path = var.external_storage_path

  # Kubernetes Configuration
  use_external_storage = true
  storage_size         = "5Gi"
  cpu_limit            = "1000m"

  # n8n Configuration
  n8n_host        = "n8n.${var.domain_suffix}"
  n8n_port        = 5678
  memory_limit_mb = 512

  # Database Configuration
  database_name    = "n8n_db"
  service_user     = "n8n_user"
  service_password = random_password.n8n_password.result
  postgres_host    = module.postgresql.postgresql_host
  postgres_user    = module.postgresql.postgresql_username

  # Encryption
  encryption_key = "n8n-homelab-encryption-key-2024"

  depends_on = [module.postgresql, module.n8n_database]
}

# Homepage moved to rainforest-iot folder
# module "homepage" removed from this homelab configuration

module "whisper" {
  source = "./modules/whisper"

  project_name         = var.project_name
  environment          = var.environment
  model_size           = "base" # Optimal for Mac CPU: fast (36x), low memory, good quality
  external_port        = 9000
  enable_gpu           = false # Set true if GPU available
  use_external_storage = true
  image_tag            = "latest"
  domain_suffix        = var.domain_suffix
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
