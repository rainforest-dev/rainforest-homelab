output "url" {
  description = "Public URL of the review app"
  value       = "https://${local.fqdn}"
}

output "container_name" {
  description = "Name of the app container"
  value       = docker_container.app.name
}
