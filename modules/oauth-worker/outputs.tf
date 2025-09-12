output "worker_name" {
  description = "Name of the deployed OAuth Worker (managed by Wrangler)"
  value       = "${var.project_name}-oauth-gateway"
}

output "worker_url" {
  description = "URL of the OAuth Worker"
  value       = "https://docker-mcp.${var.domain_suffix}"
}

output "custom_domain" {
  description = "Custom domain hostname"
  value       = cloudflare_workers_domain.oauth_gateway.hostname
}

output "claude_client_id" {
  description = "Persistent OAuth client ID for Claude MCP client (registered automatically)"
  value       = data.local_file.client_id.content
}

output "claude_client_secret" {
  description = "Persistent OAuth client secret for Claude MCP client (registered automatically)"
  value       = data.local_file.client_secret.content
  sensitive   = true
}