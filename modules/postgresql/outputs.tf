# Standard outputs
output "resource_id" {
  description = "The ID of the PostgreSQL Helm release"
  value       = helm_release.postgresql.id
}

output "service_url" {
  description = "Service URL for PostgreSQL"
  value       = "postgresql://${var.project_name}-postgresql.${var.namespace}.svc.cluster.local:5432"
}

output "service_name" {
  description = "Name of the PostgreSQL service"
  value       = "${var.project_name}-postgresql"
}

output "namespace" {
  description = "Kubernetes namespace where PostgreSQL is deployed"
  value       = var.namespace
}

# PostgreSQL-specific outputs
output "postgresql_host" {
  description = "PostgreSQL service hostname"
  value       = "${var.project_name}-postgresql.${var.namespace}.svc.cluster.local"
}

output "postgresql_port" {
  description = "PostgreSQL service port"
  value       = 5432
}

output "postgresql_database" {
  description = "Default PostgreSQL database name"
  value       = var.postgres_database
}

output "postgresql_username" {
  description = "PostgreSQL admin username"
  value       = "postgres"
}

output "postgresql_connection_string" {
  description = "PostgreSQL connection string template"
  value       = "postgresql://postgres:${random_password.postgres_password.result}@${var.project_name}-postgresql.${var.namespace}.svc.cluster.local:5432/${var.postgres_database}"
  sensitive   = true
}

# Password outputs (sensitive)
output "postgres_password" {
  description = "PostgreSQL admin password"
  value       = random_password.postgres_password.result
  sensitive   = true
}

# Storage outputs
output "pv_name" {
  description = "PostgreSQL persistent volume name"
  value       = kubernetes_persistent_volume.postgresql_pv.metadata[0].name
}

output "pvc_name" {
  description = "PostgreSQL persistent volume claim name"
  value       = kubernetes_persistent_volume_claim.postgresql_pvc.metadata[0].name
}

output "storage_path" {
  description = "External storage path for PostgreSQL data"
  value       = "${var.external_storage_path}/postgresql"
}

# Secret management outputs
output "postgresql_secret_name" {
  description = "Name of the Kubernetes secret containing PostgreSQL credentials"
  value       = kubernetes_secret.postgresql_auth.metadata[0].name
}