# Traefik output removed - using Cloudflare Tunnel

output "open_webui_id" {
  description = "The ID of the Open Web UI resource."
  value       = module.open-webui.id

}

output "flowise_id" {
  value = module.flowise.flowise_id
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

output "pgadmin_access_info" {
  description = "pgAdmin access information"
  value = {
    email            = "contact@rainforest.tools"
    internal_url     = module.postgresql.pgadmin_url
    service_name     = module.postgresql.pgadmin_service_name
    port_forward_cmd = "kubectl port-forward -n homelab svc/${module.postgresql.pgadmin_service_name} 8080:80"
  }
}

output "pgadmin_password" {
  description = "pgAdmin login password (sensitive)"
  value       = module.postgresql.pgadmin_password
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
  description = "URL to access OAuth-enabled Docker MCP Gateway"
  value       = var.oauth_client_id != "" ? module.oauth_worker[0].worker_url : null
  sensitive   = true
}

# Persistent OAuth client credentials for MCP configuration
output "claude_oauth_client_id" {
  description = "Persistent OAuth client ID for Claude MCP client configuration"
  value       = var.oauth_client_id != "" ? module.oauth_worker[0].claude_client_id : null
  sensitive   = true
}

output "claude_oauth_client_secret" {
  description = "Persistent OAuth client secret for Claude MCP client configuration"
  value       = var.oauth_client_id != "" ? module.oauth_worker[0].claude_client_secret : null
  sensitive   = true
}

# Teleport outputs
output "teleport_url" {
  description = "Teleport web UI URL"
  value       = var.enable_teleport ? module.teleport[0].public_url : null
}

output "teleport_admin_token" {
  description = "Teleport admin invitation token (keep secret!)"
  value       = var.enable_teleport ? module.teleport[0].admin_token : null
  sensitive   = true
}

output "teleport_connection_instructions" {
  description = "Instructions for connecting to Teleport"
  value       = var.enable_teleport ? module.teleport[0].connection_instructions : "Teleport is not enabled. Set enable_teleport = true in terraform.tfvars to deploy."
}
