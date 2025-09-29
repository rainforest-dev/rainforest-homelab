output "id" {
  description = "The ID of the Open Web UI resource."
  value       = var.deployment_type == "docker" ? (
    length(docker_container.open_webui) > 0 ? docker_container.open_webui[0].id : ""
  ) : (
    length(helm_release.open-webui) > 0 ? helm_release.open-webui[0].id : ""
  )
}

output "deployment_type" {
  description = "The deployment type used for Open WebUI"
  value       = var.deployment_type
}

output "container_name" {
  description = "Docker container name (only for docker deployment)"
  value       = var.deployment_type == "docker" && length(docker_container.open_webui) > 0 ? docker_container.open_webui[0].name : ""
}

output "external_port" {
  description = "External port for Open WebUI access"
  value       = var.deployment_type == "docker" ? 8080 : "N/A (Kubernetes service)"
}

output "database_configured" {
  description = "Whether PostgreSQL database is configured"
  value       = var.database_url != ""
}
