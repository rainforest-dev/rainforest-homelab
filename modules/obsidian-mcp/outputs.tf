output "service_url" {
  description = "Internal service URL for Cloudflare Tunnel routing"
  value       = "http://${var.docker_host_address}:${var.port}"
}

output "container_name" {
  description = "Docker container name"
  value       = docker_container.obsidian_mcp.name
}

output "service_name" {
  description = "Service name for module contract compatibility"
  value       = docker_container.obsidian_mcp.name
}

output "namespace" {
  description = "Logical namespace for this service"
  value       = var.project_name
}
