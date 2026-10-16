output "docker_url" {
  description = "Base URL for whisper's remote_models, reachable from containers"
  value       = "http://host.docker.internal:${var.port}"
}

output "model_name" {
  description = "Model name to request"
  value       = var.model_name
}
