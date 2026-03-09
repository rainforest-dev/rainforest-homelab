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