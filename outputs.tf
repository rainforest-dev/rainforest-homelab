# Traefik output removed - using Cloudflare Tunnel

output "open_webui_id" {
  description = "The ID of the Open Web UI resource."
  value       = module.open-webui.id

}

output "postgresql_connection_info" {
  description = "PostgreSQL connection information"
  value = {
    service_name = module.postgresql.service_name
    port         = module.postgresql.postgresql_port
    database     = module.postgresql.postgresql_database
    username     = module.postgresql.postgresql_username
  }
}

output "postgresql_admin_password" {
  description = "PostgreSQL admin password (sensitive)"
  value       = module.postgresql.postgres_password
  sensitive   = true
}

# Homepage outputs removed - homepage moved to rainforest-iot folder

output "minio_connection_info" {
  description = "MinIO connection information"
  value = {
    console_url  = "https://minio.${var.domain_suffix}"
    s3_api_url   = "https://s3.${var.domain_suffix}"
    access_key   = module.minio.access_key
    service_name = module.minio.service_name
    namespace    = module.minio.namespace
  }
}

output "minio_secret_key" {
  description = "MinIO secret key (sensitive)"
  value       = module.minio.secret_key
  sensitive   = true
}

output "oauth_worker_url" {
  description = "URL to access OAuth-enabled Docker MCP Gateway (clients auto-register via /register)"
  value       = module.oauth_worker.worker_url
}

# Teleport outputs
output "teleport_url" {
  description = "Teleport web UI URL"
  value       = var.enable_teleport ? module.teleport[0].public_url : null
}

output "teleport_connection_instructions" {
  description = "Instructions for connecting to Teleport"
  value       = var.enable_teleport ? module.teleport[0].connection_instructions : "Teleport is not enabled. Set enable_teleport = true in terraform.tfvars to deploy."
}
