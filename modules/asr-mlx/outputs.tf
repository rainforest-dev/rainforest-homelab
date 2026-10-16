output "docker_url" {
  description = "Base URL for whisper's remote_models, reachable from containers"
  value       = "http://host.docker.internal:${var.port}"
}

output "model_name" {
  description = "Model name to request"
  value       = var.model_name
}

output "ready" {
  description = "Changes once llama-swap is loaded; depend on it before routing traffic here"
  value       = null_resource.launchd.id
}
