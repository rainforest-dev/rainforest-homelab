# n8n database initialization is handled by main.tf

# Create Docker network
resource "docker_network" "n8n_network" {
  name = "${var.project_name}-n8n-network"
}

# Create n8n data volume
resource "docker_volume" "n8n_data" {
  name = "${var.project_name}-n8n-data"
  
  driver = "local"
  driver_opts = {
    type   = "none"
    o      = "bind"
    device = "${var.external_storage_path}/n8n"
  }
}

# n8n Container
resource "docker_container" "n8n" {
  name  = "${var.project_name}-n8n"
  image = "${var.n8n_image}:${var.n8n_version}"
  
  hostname = "${var.project_name}-n8n"
  
  ports {
    internal = 5678
    external = var.n8n_port
  }
  
  volumes {
    volume_name    = docker_volume.n8n_data.name
    container_path = "/home/node/.n8n"
  }
  
  networks_advanced {
    name = docker_network.n8n_network.name
  }
  
  env = [
    "NODE_ENV=production",
    "DB_TYPE=postgresdb",
    "DB_POSTGRESDB_HOST=${var.postgres_host}",
    "DB_POSTGRESDB_PORT=5432",
    "DB_POSTGRESDB_DATABASE=${var.database_name}",
    "DB_POSTGRESDB_USER=${var.service_user}",
    "DB_POSTGRESDB_PASSWORD=${var.service_password}",
    "N8N_ENCRYPTION_KEY=${var.encryption_key}",
    "N8N_HOST=${var.n8n_host}",
    "N8N_PORT=5678",
    "N8N_PROTOCOL=https",
    "WEBHOOK_URL=https://${var.n8n_host}",
    "GENERIC_TIMEZONE=${var.timezone}"
  ]
  
  memory = var.memory_limit_mb
  
  restart = "unless-stopped"
  
  # Database initialization handled externally
  
  # Health check
  healthcheck {
    test         = ["CMD", "curl", "-f", "http://localhost:5678/healthz"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "60s"
  }
}
