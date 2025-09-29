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
  value = var.enable_postgresql ? {
    service_name = module.postgresql[0].service_name
    port         = module.postgresql[0].postgresql_port
    database     = module.postgresql[0].postgresql_database
    username     = module.postgresql[0].postgresql_username
  } : null
}

output "postgresql_admin_password" {
  description = "PostgreSQL admin password (sensitive)"
  value       = var.enable_postgresql ? module.postgresql[0].postgres_password : null
  sensitive   = true
}

output "pgadmin_access_info" {
  description = "pgAdmin access information"
  value = var.enable_postgresql ? {
    email             = "contact@rainforest.tools"
    internal_url      = module.postgresql[0].pgadmin_url
    service_name      = module.postgresql[0].pgadmin_service_name
    port_forward_cmd  = "kubectl port-forward -n homelab svc/${module.postgresql[0].pgadmin_service_name} 8080:80"
  } : null
}

output "pgadmin_password" {
  description = "pgAdmin login password (sensitive)"
  value       = var.enable_postgresql ? module.postgresql[0].pgadmin_password : null
  sensitive   = true
}

output "homepage_id" {
  description = "The ID of the homepage resource."
  value       = module.homepage.resource_id
}

output "homepage_url" {
  description = "URL to access homepage dashboard"
  value       = module.homepage.service_url
}

output "minio_connection_info" {
  description = "MinIO connection information"
  value = var.enable_minio ? {
    console_url  = "https://minio.${var.domain_suffix}"
    s3_api_url   = "https://s3.${var.domain_suffix}"
    access_key   = module.minio[0].access_key
    service_name = module.minio[0].service_name
    namespace    = module.minio[0].namespace
  } : null
}

output "minio_secret_key" {
  description = "MinIO secret key (sensitive)"
  value       = var.enable_minio ? module.minio[0].secret_key : null
  sensitive   = true
}

output "oauth_worker_url" {
  description = "URL to access OAuth-enabled Docker MCP Gateway"
  value       = var.enable_docker_mcp_gateway && var.oauth_client_id != "" ? module.oauth_worker[0].worker_url : null
  sensitive   = true
}

# Persistent OAuth client credentials for MCP configuration
output "claude_oauth_client_id" {
  description = "Persistent OAuth client ID for Claude MCP client configuration"
  value       = var.enable_docker_mcp_gateway && var.oauth_client_id != "" ? module.oauth_worker[0].claude_client_id : null
  sensitive   = true
}

output "claude_oauth_client_secret" {
  description = "Persistent OAuth client secret for Claude MCP client configuration"
  value       = var.enable_docker_mcp_gateway && var.oauth_client_id != "" ? module.oauth_worker[0].claude_client_secret : null
  sensitive   = true
}
