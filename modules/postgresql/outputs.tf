output "postgresql_service_name" {
  description = "Name of the PostgreSQL service"
  value       = helm_release.postgresql.name
}

output "postgresql_port" {
  description = "PostgreSQL port"
  value       = "5432"
}

output "postgresql_database" {
  description = "PostgreSQL database name"
  value       = "postgres"
}

output "postgresql_username" {
  description = "PostgreSQL admin username"
  value       = "postgres"
}

output "postgresql_host" {
  description = "PostgreSQL service host"
  value       = "${helm_release.postgresql.name}.${helm_release.postgresql.namespace}.svc.cluster.local"
}

output "postgresql_secret_name" {
  description = "Name of the PostgreSQL secret containing passwords"
  value       = "${helm_release.postgresql.name}"
}
