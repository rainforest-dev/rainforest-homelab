# Standard outputs following homelab patterns
output "resource_id" {
  description = "The ID of the Qdrant deployment"
  value       = kubernetes_deployment.qdrant.id
}

output "service_url" {
  description = "Service URL for Qdrant HTTP API"
  value       = "http://${var.project_name}-qdrant.${var.namespace}.svc.cluster.local:6333"
}

output "service_name" {
  description = "Name of the Qdrant service"
  value       = "${var.project_name}-qdrant"
}

output "namespace" {
  description = "Kubernetes namespace where Qdrant is deployed"
  value       = var.namespace
}

# Qdrant-specific outputs
output "qdrant_http_host" {
  description = "Qdrant HTTP API hostname"
  value       = "${var.project_name}-qdrant.${var.namespace}.svc.cluster.local"
}

output "qdrant_http_port" {
  description = "Qdrant HTTP API port"
  value       = 6333
}

output "qdrant_grpc_host" {
  description = "Qdrant gRPC API hostname"
  value       = "${var.project_name}-qdrant.${var.namespace}.svc.cluster.local"
}

output "qdrant_grpc_port" {
  description = "Qdrant gRPC API port"
  value       = 6334
}

output "qdrant_http_url" {
  description = "Full Qdrant HTTP API URL"
  value       = "http://${var.project_name}-qdrant.${var.namespace}.svc.cluster.local:6333"
}

output "qdrant_grpc_url" {
  description = "Full Qdrant gRPC API URL"
  value       = "${var.project_name}-qdrant.${var.namespace}.svc.cluster.local:6334"
}

# API Key output (sensitive)
output "qdrant_api_key" {
  description = "Qdrant API key for authentication"
  value       = var.enable_api_key ? local.qdrant_api_key : null
  sensitive   = true
}

# Connection information for applications
output "connection_info" {
  description = "Connection information for applications"
  value = {
    http_url    = "http://${var.project_name}-qdrant.${var.namespace}.svc.cluster.local:6333"
    grpc_url    = "${var.project_name}-qdrant.${var.namespace}.svc.cluster.local:6334"
    api_key     = var.enable_api_key ? local.qdrant_api_key : null
    dashboard_url = var.enable_dashboard ? "http://${var.project_name}-qdrant.${var.namespace}.svc.cluster.local:6333/dashboard" : null
  }
  sensitive = true
}

# Storage outputs
output "pv_name" {
  description = "Qdrant persistent volume name"
  value       = var.use_external_storage ? kubernetes_persistent_volume.qdrant_pv[0].metadata[0].name : null
}

output "pvc_name" {
  description = "Qdrant persistent volume claim name"
  value       = kubernetes_persistent_volume_claim.qdrant_pvc.metadata[0].name
}

output "storage_path" {
  description = "External storage path for Qdrant data"
  value       = var.use_external_storage ? "${var.external_storage_path}/qdrant" : null
}

# Dashboard URL for Cloudflare Tunnel
output "dashboard_service_url" {
  description = "Dashboard service URL for external access"
  value       = var.enable_dashboard ? "http://${var.project_name}-qdrant.${var.namespace}.svc.cluster.local:6333" : null
}