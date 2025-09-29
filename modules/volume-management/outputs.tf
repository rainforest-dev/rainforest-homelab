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

output "external_path" {
  description = "Path on external storage (if using external storage)"
  value       = var.use_external_storage ? local.volume_path : null
}

output "storage_type" {
  description = "Storage type being used"
  value       = var.use_external_storage ? "external" : "docker"
}