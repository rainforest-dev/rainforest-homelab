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
    service_name = module.postgresql[0].postgresql_service_name
    port         = module.postgresql[0].postgresql_port
    database     = module.postgresql[0].postgresql_database
    username     = module.postgresql[0].postgresql_username
  } : null
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
}
