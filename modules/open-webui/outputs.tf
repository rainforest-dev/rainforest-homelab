output "resource_id" {
  description = "The ID of the Open Web UI resource."
  value       = helm_release.open-webui.id
}

output "service_url" {
  description = "Open WebUI service URL"
  value       = "http://${var.project_name}-open-webui.${var.namespace}.svc.cluster.local:80"
}

output "service_name" {
  description = "Open WebUI service name"
  value       = "${var.project_name}-open-webui"
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = var.namespace
}

# Legacy output for backward compatibility
output "id" {
  description = "The ID of the Open Web UI resource."
  value       = helm_release.open-webui.id
}

output "database_config" {
  description = "Database configuration status"
  value = {
    external_database_enabled = var.enable_external_database
    database_host            = var.database_host
    database_name            = var.database_name
    uses_external_storage    = var.enable_external_database || var.enable_s3_storage
  }
}

output "storage_config" {
  description = "Storage configuration status"
  value = {
    s3_enabled   = var.enable_s3_storage
    s3_endpoint  = var.s3_endpoint
    s3_bucket    = var.s3_bucket
    persistence_enabled = var.enable_persistence && !var.enable_external_database
  }
}
