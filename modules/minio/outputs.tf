output "minio_service_name" {
  description = "The name of the MinIO service"
  value       = helm_release.minio.name
}

output "minio_console_port" {
  description = "The port for MinIO console"
  value       = 9001
}

output "minio_api_port" {
  description = "The port for MinIO S3 API"
  value       = 9000
}