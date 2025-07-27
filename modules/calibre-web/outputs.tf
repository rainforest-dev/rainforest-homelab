# Standard outputs
output "resource_id" {
  description = "The ID of the Calibre Web Docker container"
  value       = docker_container.calibre-web.id
}

output "service_url" {
  description = "Service URL for Calibre Web"
  value       = "https://calibre.k8s.orb.local"
}

output "service_name" {
  description = "Name of the Calibre Web service"
  value       = docker_container.calibre-web.name
}

output "namespace" {
  description = "Namespace where Calibre Web is deployed (Docker container, no K8s namespace)"
  value       = "docker"
}

# Service-specific outputs
output "container_name" {
  description = "Docker container name for Calibre Web"
  value       = docker_container.calibre-web.name
}

output "internal_port" {
  description = "Internal port for Calibre Web container"
  value       = var.internal_port
}

output "external_port" {
  description = "External port for Calibre Web container"
  value       = var.external_port
}

output "image" {
  description = "Docker image used for Calibre Web"
  value       = docker_container.calibre-web.image
}

output "books_path" {
  description = "Host path to books library"
  value       = var.books_path
}

output "config_path" {
  description = "Host path to configuration directory"
  value       = "${abspath(path.root)}/configs/calibre-web"
}