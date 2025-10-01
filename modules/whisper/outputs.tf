output "service_url" {
  description = "Internal service URL (accessible via host.docker.internal)"
  value       = "http://host.docker.internal:${var.external_port}"
}

output "external_url" {
  description = "External HTTPS URL via Cloudflare Tunnel"
  value       = var.domain_suffix != "" ? "https://whisper.${var.domain_suffix}" : ""
}

output "container_name" {
  description = "Docker container name"
  value       = docker_container.whisper.name
}

output "container_id" {
  description = "Docker container ID"
  value       = docker_container.whisper.id
}

output "model_size" {
  description = "Whisper model size in use"
  value       = var.model_size
}

output "api_endpoint" {
  description = "OpenAI-compatible API endpoint"
  value       = "http://host.docker.internal:${var.external_port}/v1/audio/transcriptions"
}