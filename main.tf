# Random passwords for database services
# Open WebUI password - DISABLED (using SQLite instead of PostgreSQL)
# resource "random_password" "open_webui_password" {
#   length  = 24
#   special = true
# }


resource "random_password" "n8n_password" {
  length  = 24
  special = true
}

resource "random_password" "n8n_encryption_key" {
  length  = 48
  special = false
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


  # Monitoring
  enable_metrics = false
}

# Docker MCP Gateway runs as a launchd host service (the "managed" gateway), NOT a
# Terraform-managed container. It executes:
#   docker mcp gateway run --profile default --transport sse --port 3101 --host 0.0.0.0
# which reads config from the `default` profile and secrets from Docker Desktop's
# Keychain — something a plain `docker run` container cannot reach, which is why the
# old standalone container needed plaintext secrets in config.yaml.
#   Plist (version-controlled): configs/docker-mcp-gateway/com.homelab.docker-mcp-gateway.plist
#   Install: cp that plist to ~/Library/LaunchAgents/ && launchctl load -w <plist>
# The Cloudflare Tunnel route (docker-mcp-internal in locals.tf) points at
# host.docker.internal:3101 — unchanged from the retired container's published port.

# OAuth Worker for Docker MCP Gateway
# Clients (Claude.ai, Claude Code) auto-register via RFC 7591 Dynamic Client Registration
module "oauth_worker" {
  source = "./modules/oauth-worker"

  project_name          = var.project_name
  environment           = var.environment
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = module.cloudflare_tunnel.zone_id
  cloudflare_team_name  = var.cloudflare_team_name
  domain_suffix         = var.domain_suffix

  enable_memories_mcp     = var.enable_personal_memories
  memories_gateway_secret = var.enable_personal_memories ? random_password.memories_mcp_secret[0].result : null
  calibre_gateway_secret  = random_password.calibre_mcp_secret.result
  library_gateway_secret  = random_password.library_mcp_secret.result

  enable_n8n_mcp = var.enable_n8n_mcp
  n8n_mcp_token  = var.n8n_mcp_token
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
  cpu_limit          = "2"
  memory_limit       = "1536Mi"
  enable_persistence = var.enable_persistence
  storage_size       = var.default_storage_size
  ollama_enabled     = false
  ollama_base_url    = var.ollama_base_url
  chart_repository   = "https://helm.openwebui.com/"
  chart_version      = "10.2.1" # Updated to latest version

  # Switch to Helm deployment with PostgreSQL database
  deployment_type = "helm"
  database_url    = "" # Use SQLite (default) instead of PostgreSQL to avoid migration bugs

  # External storage configuration
  use_external_storage  = true
  external_storage_path = var.external_storage_path

  # Whisper STT integration — use the INTERNAL address, not the public tunnel URL.
  # whisper.<domain> is behind Cloudflare Access, which 302-redirects API calls to a
  # login page; open-webui then fails to transcribe (same failure mode n8n's API hit).
  # Both services run on this machine, so there is no reason to leave the LAN.
  whisper_stt_url = "http://host.docker.internal:9090"
  domain_suffix   = var.domain_suffix


  # Image generation integration
  image_gen_url     = var.enable_comfyui_adapter ? "https://image-gen.${var.domain_suffix}" : ""
  image_gen_api_key = var.image_gen_api_key

  # Pinned image version (used by docker deployment_type)
  image_version = var.open_webui_image_version

  # No longer depends on PostgreSQL database - using SQLite
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



module "minio" {
  source = "./modules/minio"

  project_name         = var.project_name
  environment          = var.environment
  enable_persistence   = var.enable_persistence
  storage_size         = var.minio_storage_size
  cpu_limit            = var.default_cpu_limit
  memory_limit         = var.default_memory_limit
  chart_repository     = "https://charts.min.io/"
  chart_version        = "5.4.0"
  use_external_storage = true # Enable external storage on Samsung T7
}

# OpenSpeedTest moved to Raspberry Pi (external hosting)
# Module kept in /modules for reference if needed


module "personal-calibre" {
  source = "./modules/personal-calibre"

  project_name         = var.project_name
  environment          = var.environment
  docker_host          = var.docker_host
  image                = var.personal_calibre_image
  external_port        = 8082
  calibre_library_path = var.calibre_library_path
  mcp_secret           = random_password.calibre_mcp_secret.result
  # Half of the old 512Mi: notebooks, OCR and image work moved to personal-notebook.
  memory_limit = "256Mi"
  # Calibre still lists the notebook MCP tools and forwards each call to personal-notebook, and
  # passes /api/inbox/bujo through. Old /notebooks links redirect in the app itself.
  notebook_internal_url = module.personal-notebook.internal_url
  notebook_mcp_secret   = random_password.notebook_mcp_secret.result
}

module "personal-notebook" {
  source = "./modules/personal-notebook"

  project_name = var.project_name
  environment  = var.environment
  docker_host  = var.docker_host
  image        = var.personal_notebook_image
  mcp_secret   = random_password.notebook_mcp_secret.result
  inbox_secret = random_password.inbox_secret.result
  ocr_model    = var.notebook_ocr_model
  # First start copies calibre's notebooks from its volume (read-only), then never reads it again.
  import_volume = module.personal-calibre.app_data_volume
}

# Shared by personal-calibre (x-notebook-gateway) and personal-notebook's /notebooks/mcp
resource "random_password" "notebook_mcp_secret" {
  length  = 48
  special = false
}

resource "random_password" "calibre_mcp_secret" {
  length  = 48
  special = false
}

# Shared by the OAuth Worker (x-library-gateway) and library-hall's /api/mcp
resource "random_password" "library_mcp_secret" {
  length  = 48
  special = false
}

# Shared by the n8n inbox workflow and the apps it delivers to (x-inbox-secret)
resource "random_password" "inbox_secret" {
  length  = 48
  special = false
}

resource "random_password" "inbox_upload_secret" {
  length  = 48
  special = false
}

# The hall at / of library.rainforest.tools; reads every collection's hall items without Cloudflare.
module "library-hall" {
  source = "./modules/library-hall"

  project_name = var.project_name
  environment  = var.environment
  docker_host  = var.docker_host
  image        = var.library_hall_image
  collection_urls = {
    books     = "${module.personal-calibre.tunnel_service_url}/books"
    notebooks = module.personal-notebook.internal_url
    rack      = "${module.rss-manager.tunnel_service_url}/rack"
    kb        = "${module.rss-manager.tunnel_service_url}/kb"
  }
  vault_system_path = var.vault_registry_path

  # The library MCP: the hall checks mcp_secret, and forwards the book and notebook tools to
  # calibre and personal-notebook with their own gateway secrets.
  mcp_secret = random_password.library_mcp_secret.result
  collection_mcp_secrets = {
    books     = random_password.calibre_mcp_secret.result
    notebooks = random_password.notebook_mcp_secret.result
  }
}

module "rss-manager" {
  source = "./modules/rss-manager"

  project_name        = var.project_name
  environment         = var.environment
  docker_host         = var.docker_host
  image               = var.rss_manager_image
  external_port       = 8084
  vault_registry_path = var.vault_registry_path
  kb_wiki_pages_path  = var.kb_wiki_pages_path
  kb_readwise_path    = var.kb_readwise_path
}

module "personal-memories" {
  source = "./modules/personal-memories"
  count  = var.enable_personal_memories ? 1 : 0

  project_name        = var.project_name
  environment         = var.environment
  docker_host         = var.docker_host
  image               = var.personal_memories_image
  external_port       = 3004
  data_dir            = var.memories_data_dir
  photos_library_path = var.memories_photos_library_path
  notes_dir           = var.memories_notes_dir
  owner_names         = var.memories_owner_names
  public_url          = "https://memories.${var.domain_suffix}"
  mcp_secret          = random_password.memories_mcp_secret[0].result
}

resource "random_password" "memories_mcp_secret" {
  count   = var.enable_personal_memories ? 1 : 0
  length  = 48
  special = false
}

module "hermes_backup" {
  source = "./modules/hermes-backup"
  count  = var.enable_hermes_backup ? 1 : 0
}

module "memories_auto_import" {
  source = "./modules/memories-auto-import"
  count  = var.enable_memories_auto_import ? 1 : 0

  runner_ref          = var.memories_runner_ref
  data_dir            = var.memories_data_dir
  photos_library_path = var.memories_photos_library_path
  photos_from         = var.memories_photos_from
  drop_dir            = "${pathexpand(var.inbox_host_path)}/memories"
  webhook_url         = "http://localhost:${module.n8n.n8n_port}/webhook/ha-events"
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
  n8n_version     = "2.43.8" # upgrade steps: configs/n8n/README.md "Upgrading n8n"
  n8n_host        = "n8n.${var.domain_suffix}"
  n8n_port        = 5678
  memory_limit_mb = 1536

  # Database Configuration
  database_name    = "n8n_db"
  service_user     = "n8n_user"
  service_password = random_password.n8n_password.result
  postgres_host    = module.postgresql.postgresql_host
  postgres_user    = module.postgresql.postgresql_username

  # Encryption
  encryption_key = random_password.n8n_encryption_key.result

  # Shared inbox: only the iCloud Inbox/ folder is mounted into the pod
  inbox_host_path = pathexpand(var.inbox_host_path)

  depends_on = [module.postgresql, module.n8n_database]
}

# Homepage moved to rainforest-iot folder
# module "homepage" removed from this homelab configuration

resource "random_password" "asr_mlx_api_key" {
  count   = var.enable_asr_mlx ? 1 : 0
  length  = 40
  special = false
}

module "asr_mlx" {
  count  = var.enable_asr_mlx ? 1 : 0
  source = "./modules/asr-mlx"

  api_key = random_password.asr_mlx_api_key[0].result
}

module "whisper" {
  source = "./modules/whisper"

  project_name = var.project_name
  environment  = var.environment
  # base garbled Mandarin and looped on long recordings (2026-10-14 voice memos);
  # turbo is large-v3 with a 4-layer decoder, so near large-v3 accuracy at a fraction of the cost.
  model_size            = var.enable_asr_mlx ? module.asr_mlx[0].model_name : "large-v3-turbo"
  remote_models         = var.enable_asr_mlx ? { (module.asr_mlx[0].model_name) = module.asr_mlx[0].docker_url } : {}
  remote_fallback_model = var.enable_asr_mlx ? "large-v3-turbo" : ""
  remote_api_key        = var.enable_asr_mlx ? random_password.asr_mlx_api_key[0].result : ""

  depends_on = [module.asr_mlx]
  # Port 9000 reserved for MinIO (infrastructure > app).
  # Cloudflare Tunnel routes to whisper.rainforest.tools regardless of port.
  external_port = 9090
  # An 18-minute recording peaked at 2.72 of 3 GiB on large-v3-turbo.
  memory_limit         = "4Gi"
  enable_gpu           = false # Set true if GPU available
  use_external_storage = true
  image_tag            = "latest"
  domain_suffix        = var.domain_suffix
}

module "comfyui_adapter" {
  count  = var.enable_comfyui_adapter ? 1 : 0
  source = "./modules/comfyui-adapter"

  project_name  = var.project_name
  environment   = var.environment
  comfyui_host  = var.comfyui_host
  api_key       = var.image_gen_api_key
  external_port = 7860
  image_tag     = "latest"
  domain_suffix = var.domain_suffix
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

# Only needed for Teleport direct access today: issues the proxy's public cert.
module "cert_manager" {
  count  = var.enable_teleport && var.teleport_direct_access ? 1 : 0
  source = "./modules/cert-manager"

  acme_email           = var.acme_email
  cloudflare_api_token = var.cloudflare_api_token
}

module "teleport" {
  count  = var.enable_teleport ? 1 : 0
  source = "./modules/teleport"

  project_name            = var.project_name
  namespace               = "homelab"
  public_hostname         = "tp.${var.domain_suffix}"
  kubernetes_cluster_name = var.kubernetes_context
  teleport_version        = "15.5.4"
  memory_limit            = "1Gi"
  storage_size            = "10Gi"
  use_external_storage    = false # exFAT on Samsung T7 doesn't support Unix sockets needed by Teleport v15.5+
  external_storage_path   = var.external_storage_path

  # Cloudflare's free plan serves HiNet from San Jose, so every Teleport hop
  # through the tunnel costs ~300 ms. Direct access lets Taiwan clients and
  # agents reach the proxy over the LAN or tailnet instead (see the module README).
  direct_access            = var.teleport_direct_access
  cert_manager_issuer_name = var.teleport_direct_access ? module.cert_manager[0].issuer_name : ""

  depends_on = [kubernetes_namespace.homelab, module.cert_manager]
}

module "cloudflare_tunnel" {
  source = "./modules/cloudflare-tunnel"

  project_name               = var.project_name
  domain_suffix              = var.domain_suffix
  cloudflare_account_id      = var.cloudflare_account_id
  cloudflare_api_token       = var.cloudflare_api_token
  kubernetes_namespace       = "homelab"
  allowed_email_domains      = var.allowed_email_domains
  allowed_emails             = var.allowed_emails
  service_token_ids          = var.service_token_ids
  google_oauth_client_id     = var.google_oauth_client_id
  google_oauth_client_secret = var.google_oauth_client_secret
  services                   = local.services
  cloudflared_version        = var.cloudflared_version

  depends_on = [kubernetes_namespace.homelab]
}

# grafana-mcp folded into the Docker MCP Gateway (default profile). The standalone
# container was retired; Grafana MCP tools now arrive via docker-mcp.rainforest.tools.
# grafana.url and grafana.api_key live in the gateway profile + Keychain, not Terraform:
#   docker mcp profile config default --set grafana.url=http://<PI_IP>:30080
#   printf '<viewer-token>' | docker mcp secret set grafana.api_key

module "speedtest_exporter" {
  source = "./modules/speedtest-exporter"

  project_name = var.project_name
  log_opts     = {}
}

module "grafana_alloy" {
  source = "./modules/grafana-alloy"

  machine                     = "rainforest-mini"
  project_name                = var.project_name
  image_version               = var.grafana_alloy_version
  prometheus_remote_write_url = var.rpi_prometheus_url
  loki_push_url               = var.rpi_loki_url
  tempo_otlp_url              = "http://${var.raspberry_pi_ip}:30418"
  kubeconfig_path             = var.alloy_kubeconfig_path
  log_opts                    = {}
}

module "docker_stats_metrics" {
  source = "./modules/docker-stats-metrics"

  macos_username = var.macos_username
}

# ComfyUI — standalone Python server managed by launchd (macOS)
# Port 8000 is now free since ComfyUI Desktop (Electron) is uninstalled.
# Access UI at http://localhost:8000; comfyui-adapter reaches it via host.docker.internal:8000
module "comfyui" {
  source = "./modules/comfyui"

  port               = 8000
  model_paths_config = "~/Library/Application Support/ComfyUI/extra_models_config.yaml"
  log_dir            = "~/Library/Logs/ComfyUI"
}

resource "docker_container" "dockerproxy" {
  image   = "ghcr.io/tecnativa/docker-socket-proxy:latest"
  name    = "dockerproxy"
  restart = "always"
  env     = ["CONTAINERS=1", "SERVICES=1", "TASKS=1", "POST=0"]
  ports {
    internal = 2375
    external = 2375
    ip       = "127.0.0.1"
  }
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }
}

# ─── Mac-side backup (Theme C1) ─────────────────────────────────────────────
# Nightly logical dump of Postgres (all n8n/flowise data), then an offen backup
# container ships the app volumes + that dump to MinIO. Closes the Mac-side gap
# the Theme C audit found (the Pi was covered; the Mac was not).

module "postgres_backup" {
  source         = "./modules/postgres-backup"
  namespace      = "homelab"
  dump_host_path = "${var.external_storage_path}/postgres-backups"
}

module "docker_volume_backup" {
  source                  = "./modules/docker-volume-backup"
  minio_access_key        = module.minio.access_key
  minio_secret_key        = module.minio.secret_key
  postgres_dump_host_path = "${var.external_storage_path}/postgres-backups"
}

# Mirrors MinIO onto the T7 so Synology Drive Client carries the backups offsite.
# Runs last (03:45), after the Pi and Mac backups have finished uploading.
module "minio_t7_sync" {
  source    = "./modules/minio-t7-sync"
  namespace = "homelab"
  t7_path   = "${var.external_storage_path}/minio-backup"
}

# Alerts into the Obsidian daily note when a backup stops arriving. Closes the gap
# that let the 2026-07 backup outage run silently for days.
module "backup_monitor" {
  source    = "./modules/backup-monitor"
  namespace = "homelab"
  t7_path   = "${var.external_storage_path}/minio-backup"
}
