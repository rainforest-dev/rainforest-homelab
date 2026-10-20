output "container_name" {
  description = "Name of the Docker container"
  value       = docker_container.personal_notebook.name
}

output "external_port" {
  description = "Host port the app is listening on"
  value       = var.external_port
}

output "data_volume" {
  description = "Name of the Docker volume holding the notebook DB, page images and search index"
  value       = docker_volume.data.name
}

output "tunnel_service_url" {
  description = "Internal URL for Cloudflare Tunnel routing"
  value       = "http://host.docker.internal:${var.external_port}"
}

output "internal_url" {
  description = "The app as other containers reach it, base path included"
  value       = "http://host.docker.internal:${var.external_port}/notebooks"
}
