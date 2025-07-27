output "volume_id" {
  description = "Docker volume ID"
  value       = docker_volume.volume.id
}

output "volume_name" {
  description = "Docker volume name"
  value       = docker_volume.volume.name
}

output "volume_mountpoint" {
  description = "Docker volume mountpoint"
  value       = docker_volume.volume.mountpoint
}

output "volume_labels" {
  description = "Docker volume labels"
  value       = docker_volume.volume.labels
}