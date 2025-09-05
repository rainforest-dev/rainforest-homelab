output "resource_id" {
  description = "MinIO Helm release name"
  value       = helm_release.minio.name
}

output "service_url" {
  description = "MinIO service URL for S3 API"
  value       = "http://${var.project_name}-minio.${var.namespace}.svc.cluster.local:9000"
}

output "console_url" {
  description = "MinIO console URL"
  value       = var.console_enabled ? "http://${var.project_name}-minio-console.${var.namespace}.svc.cluster.local:9001" : null
}

output "service_name" {
  description = "MinIO service name"
  value       = "${var.project_name}-minio"
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = var.namespace
}

output "access_key" {
  description = "MinIO access key (root user)"
  value       = var.minio_root_user
  sensitive   = false
}

output "secret_key" {
  description = "MinIO secret key (root password)"
  value       = local.minio_password
  sensitive   = true
}

output "s3_endpoint" {
  description = "S3-compatible endpoint for applications"
  value       = "${var.project_name}-minio.${var.namespace}.svc.cluster.local:9000"
}

output "console_service_name" {
  description = "MinIO console service name"
  value       = var.console_enabled ? "${var.project_name}-minio-console" : null
}