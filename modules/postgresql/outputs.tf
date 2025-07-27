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
