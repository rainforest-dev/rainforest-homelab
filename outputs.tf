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

output "memories_mcp_secret" {
  description = "Shared secret between the OAuth Worker and the memories container (x-memories-gateway)"
  value       = var.enable_personal_memories ? random_password.memories_mcp_secret[0].result : null
  sensitive   = true
}

output "calibre_mcp_secret" {
  description = "Shared secret between the OAuth Worker and the personal-calibre container (x-calibre-gateway)"
  value       = random_password.calibre_mcp_secret.result
  sensitive   = true
}

output "service_auth_client_id" {
  description = "CF Access service token client ID the OAuth Worker sends to service_auth_only origins"
  value       = module.cloudflare_tunnel.service_auth_client_id
}

output "service_auth_client_secret" {
  description = "CF Access service token client secret the OAuth Worker sends to service_auth_only origins"
  value       = module.cloudflare_tunnel.service_auth_client_secret
  sensitive   = true
}

output "memories_auto_import" {
  description = "launchd job, runner and log locations for memories auto-import"
  value       = var.enable_memories_auto_import ? module.memories_auto_import[0] : null
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
