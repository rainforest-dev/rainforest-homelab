output "server_url" {
  description = "MCPO server URL for local access"
  value       = "http://localhost:8090"
}

output "docs_url" {
  description = "MCPO OpenAPI documentation URL"
  value       = "http://localhost:8090/docs"
}

output "config_file" {
  description = "MCPO configuration file path"
  value       = local_file.mcpo_config.filename
}
