# Standard outputs
output "resource_id" {
  description = "The ID of the OpenSpeedTest Docker container"
  value       = docker_container.openspeedtest.id
}

output "service_url" {
  description = "Service URL for OpenSpeedTest"
  value       = "https://openspeedtest.k8s.orb.local"
}

output "service_name" {
  description = "Name of the OpenSpeedTest service"
  value       = docker_container.openspeedtest.name
}

output "namespace" {
  description = "Namespace where OpenSpeedTest is deployed (Docker container, no K8s namespace)"
  value       = "docker"
}

# Service-specific outputs
output "container_name" {
  description = "Docker container name for OpenSpeedTest"
  value       = docker_container.openspeedtest.name
}

output "container_id" {
  description = "Docker container ID for OpenSpeedTest"
  value       = docker_container.openspeedtest.id
}

output "image_id" {
  description = "Docker image ID used for OpenSpeedTest"
  value       = docker_image.openspeedtest.image_id
}

output "image_name" {
  description = "Docker image name for OpenSpeedTest"
  value       = var.image_name
}

output "internal_port" {
  description = "Internal port for OpenSpeedTest container"
  value       = var.internal_port
}

output "external_port" {
  description = "External port for OpenSpeedTest container"
  value       = var.external_port
}

output "keep_locally" {
  description = "Whether Docker image is kept locally after destroy"
  value       = var.keep_locally
}