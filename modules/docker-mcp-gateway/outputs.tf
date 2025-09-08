# Standard module outputs following homelab patterns

output "resource_id" {
  description = "Docker MCP Gateway container ID"
  value       = docker_container.docker_mcp_gateway.id
}

output "container_name" {
  description = "Docker MCP Gateway container name"
  value       = docker_container.docker_mcp_gateway.name
}

output "service_url" {
  description = "Docker MCP Gateway service URL for local access"
  value       = "http://localhost:${var.port}"
}

# External access outputs

output "external_url" {
  description = "External URL for Docker MCP Gateway (when Cloudflare Tunnel is enabled)"
  value       = var.enable_cloudflare_tunnel && var.domain_suffix != "" ? "https://${var.tunnel_hostname}.${var.domain_suffix}" : null
}

output "tunnel_hostname" {
  description = "Hostname used for Cloudflare Tunnel routing"
  value       = var.tunnel_hostname
}

# Container information outputs

output "port" {
  description = "Port on which Docker MCP Gateway is listening"
  value       = var.port
}

output "image" {
  description = "Docker image used for MCP Gateway"
  value       = var.docker_image
}

output "container_status" {
  description = "Docker container status"
  value       = docker_container.docker_mcp_gateway.must_run
}