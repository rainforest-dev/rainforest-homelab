output "container_name" {
  description = "Name of the Docker container"
  value       = docker_container.finance_audit.name
}

output "external_port" {
  description = "Host port the app is listening on"
  value       = var.external_port
}

output "tunnel_service_url" {
  description = "Internal URL for Cloudflare Tunnel routing"
  value       = "http://host.docker.internal:${var.external_port}"
}

output "health_url" {
  description = "Health endpoint (nginx returns 200 without touching the filesystem)"
  value       = "http://host.docker.internal:${var.external_port}/healthz"
}
