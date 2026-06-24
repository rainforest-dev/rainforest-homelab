output "service_url" {
  description = "Internal URL accessible from Docker host"
  value       = "http://host.docker.internal:${var.external_port}"
}

output "tunnel_service_url" {
  description = "Internal URL for Cloudflare Tunnel routing"
  value       = "http://host.docker.internal:${var.external_port}"
}

output "external_url" {
  description = "External HTTPS URL via Cloudflare Tunnel"
  value       = var.domain_suffix != "" ? "https://image-gen.${var.domain_suffix}" : ""
}

output "api_endpoint" {
  description = "OpenAI-compatible image generation endpoint"
  value       = "http://host.docker.internal:${var.external_port}/v1/images/generations"
}

output "container_name" {
  description = "Docker container name"
  value       = docker_container.comfyui_adapter.name
}
