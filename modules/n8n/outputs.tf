# Standard outputs
output "resource_id" {
  description = "The ID of the n8n deployment"
  value       = kubernetes_deployment.n8n.id
}

output "service_url" {
  description = "Service URL for n8n"
  value       = "http://${kubernetes_service.n8n.metadata[0].name}.${var.namespace}.svc.cluster.local:5678"
}

output "service_name" {
  description = "Name of the n8n service"
  value       = kubernetes_service.n8n.metadata[0].name
}

output "namespace" {
  description = "Kubernetes namespace where n8n is deployed"
  value       = var.namespace
}

# n8n-specific outputs
output "n8n_host" {
  description = "n8n hostname for webhooks"
  value       = var.n8n_host
}

output "n8n_port" {
  description = "n8n service port"
  value       = var.n8n_port
}

output "database_name" {
  description = "n8n database name"
  value       = var.database_name
}

output "service_user" {
  description = "n8n database user"
  value       = var.service_user
}

# Storage outputs
output "pv_name" {
  description = "n8n persistent volume name"
  value       = var.use_external_storage ? kubernetes_persistent_volume.n8n_pv[0].metadata[0].name : null
}

output "pvc_name" {
  description = "n8n persistent volume claim name"
  value       = var.use_external_storage ? kubernetes_persistent_volume_claim.n8n_pvc[0].metadata[0].name : null
}

output "storage_path" {
  description = "External storage path for n8n data"
  value       = var.use_external_storage ? "${var.external_storage_path}/n8n" : null
}