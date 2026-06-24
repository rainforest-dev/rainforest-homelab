output "service_url" {
  description = "Internal service URL for Cloudflare Tunnel routing"
  value       = "http://host.docker.internal:${var.port}"
}

output "container_name" {
  description = "Docker container name"
  value       = docker_container.obsidian_mcp.name
}
