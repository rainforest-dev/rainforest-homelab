output "container_id" {
  description = "ID of the container"
  value       = docker_container.nginx.id
}

output "image_id" {
  description = "ID of the image"
  value       = docker_image.nginx.id
}
