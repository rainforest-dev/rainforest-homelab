output "container_name" {
  description = "Name of the Docker container"
  value       = docker_container.personal_calibre.name
}

output "external_port" {
  description = "Host port the app is listening on"
  value       = var.external_port
}

output "app_data_volume" {
  description = "Name of the Docker volume holding the app DB"
  value       = docker_volume.app_data.name
}

output "tunnel_service_url" {
  description = "Internal URL for Cloudflare Tunnel routing"
  value       = "http://host.docker.internal:${var.external_port}"
}
