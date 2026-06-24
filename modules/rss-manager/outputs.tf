output "container_name" {
  description = "Name of the Docker container"
  value       = docker_container.rss_manager.name
}

output "external_port" {
  description = "Host port the app is listening on"
  value       = var.external_port
}

output "tunnel_service_url" {
  description = "Internal URL for Cloudflare Tunnel routing"
  value       = "http://host.docker.internal:${var.external_port}"
}
