output "ingress_id" {
  description = "The ID of the ingress resource."
  value       = module.ingress.ingress_id
}

output "flowise_id" {
  value = module.flowise.flowise_id
}

output "postgresql_connection_info" {
  description = "PostgreSQL connection information"
  value = {
    service_name = module.postgresql.postgresql_service_name
    port         = module.postgresql.postgresql_port
    database     = module.postgresql.postgresql_database
    username     = module.postgresql.postgresql_username
  }
}
