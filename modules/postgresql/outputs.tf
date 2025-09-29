# PostgreSQL Connection Information
output "postgres_host" {
  description = "PostgreSQL host for container-to-container communication"
  value       = docker_container.postgres.name
}

output "postgres_port" {
  description = "PostgreSQL internal port"
  value       = 5432
}

output "postgres_external_port" {
  description = "PostgreSQL external port (Tailscale access)"
  value       = var.postgres_external_port
}

output "postgres_user" {
  description = "PostgreSQL superuser username"
  value       = var.postgres_user
}

output "postgres_password" {
  description = "PostgreSQL superuser password"
  value       = local.postgres_password
  sensitive   = true
}

output "postgres_database" {
  description = "Default PostgreSQL database name"
  value       = var.postgres_database
}

# Database Connection Template for Services
output "database_connection_template" {
  description = "Template for services to build their own database connections"
  value = {
    host     = docker_container.postgres.name
    port     = 5432
    user     = var.postgres_user
    password = local.postgres_password
    # Services append their own database name: postgresql://user:pass@host:port/service_db
  }
  sensitive = true
}

# pgAdmin Access Information
output "pgadmin_url" {
  description = "pgAdmin access URL (via Tailscale)"
  value       = "http://100.86.67.66:${var.pgadmin_external_port}"
}

output "pgadmin_email" {
  description = "pgAdmin admin email"
  value       = var.pgadmin_email
}

output "pgadmin_password" {
  description = "pgAdmin admin password"
  value       = local.pgadmin_password
  sensitive   = true
}

# Storage Information
output "postgres_storage_path" {
  description = "PostgreSQL data storage path on external disk"
  value       = "${local.external_storage_base}/postgresql"
}

output "pgadmin_storage_path" {
  description = "pgAdmin data storage path on external disk"
  value       = "${local.external_storage_base}/pgadmin"
}

# Network Information
output "postgres_network_name" {
  description = "Docker network name for PostgreSQL stack"
  value       = docker_network.postgres_network.name
}

# Container Information
output "postgres_container_id" {
  description = "PostgreSQL container ID"
  value       = docker_container.postgres.id
}

output "pgadmin_container_id" {
  description = "pgAdmin container ID"
  value       = docker_container.pgadmin.id
}

# Database Management
output "postgres_container_name" {
  description = "PostgreSQL container name for service database initialization"
  value       = docker_container.postgres.name
}