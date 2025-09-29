output "database_name" {
  description = "Name of the created database"
  value       = var.database_name
}

output "service_name" {
  description = "Name of the service that owns this database"
  value       = var.service_name
}

output "database_created" {
  description = "Whether the database was created"
  value       = var.create_database
}

output "database_user" {
  description = "Database user for the service"
  value       = var.service_user != "" ? var.service_user : var.postgres_user
}

output "connection_info" {
  description = "Database connection information"
  value = {
    database_name = var.database_name
    user         = var.service_user != "" ? var.service_user : var.postgres_user
    host         = var.postgres_host
    port         = 5432
  }
}

output "initialization_status" {
  description = "Database initialization completion status"
  value       = var.create_database ? "completed" : "skipped"
}