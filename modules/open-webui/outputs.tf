output "id" {
  description = "The ID of the Open Web UI resource."
  value       = helm_release.open-webui.id
}

output "mcpo_config" {
  description = "MCPO configuration details"
  value = var.mcpo_enabled ? {
    enabled               = var.mcpo_enabled
    config_map_name       = kubernetes_config_map.mcpo_config[0].metadata[0].name
    docker_socket_enabled = var.enable_docker_socket
    mcp_servers           = var.mcp_servers_config
  } : null
}
