output "traefik_id" {
  description = "The ID of the traefik resource."
  value       = var.enable_traefik ? module.traefik[0].traefik_id : null
}

output "open_webui_id" {
  description = "The ID of the Open Web UI resource."
  value       = module.open-webui.id

}

output "flowise_id" {
  value = module.flowise.flowise_id
}

output "postgresql_connection_info" {
  description = "PostgreSQL connection information"
  value = var.enable_postgresql ? {
    service_name = module.postgresql[0].postgresql_service_name
    port         = module.postgresql[0].postgresql_port
    database     = module.postgresql[0].postgresql_database
    username     = module.postgresql[0].postgresql_username
  } : null
}
