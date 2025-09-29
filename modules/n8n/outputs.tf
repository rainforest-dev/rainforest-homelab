# Standard outputs
output "resource_id" {
  description = "The ID of the n8n container"
  value       = docker_container.n8n.id
}

output "service_url" {
  description = "Service URL for n8n"
  value       = "https://${var.n8n_host}"
}

output "service_name" {
  description = "Name of the n8n container"
  value       = docker_container.n8n.name
}

output "container_ip" {
  description = "IP address of the n8n container"
  value       = docker_container.n8n.network_data[0].ip_address
}

# Service-specific outputs
output "container_name" {
  description = "Docker container name for n8n"
  value       = docker_container.n8n.name
}

output "container_image" {
  description = "Docker image used for n8n"
  value       = docker_container.n8n.image
}

output "external_port" {
  description = "External port for n8n service"
  value       = var.n8n_port
}

output "database_name" {
  description = "PostgreSQL database name for n8n"
  value       = var.database_name
}

output "database_user" {
  description = "PostgreSQL user for n8n"
  value       = var.service_user
  sensitive   = true
}

output "network_name" {
  description = "Docker network name for n8n"
  value       = docker_network.n8n_network.name
}

output "volume_name" {
  description = "Docker volume name for n8n data"
  value       = docker_volume.n8n_data.name
}