output "service_name" {
  description = "Name of the MCP Gateway Kubernetes service"
  value       = kubernetes_service.mcp_gateway.metadata[0].name
}

output "service_namespace" {
  description = "Namespace of the MCP Gateway service"
  value       = kubernetes_service.mcp_gateway.metadata[0].namespace
}

output "service_port" {
  description = "Port of the MCP Gateway service"
  value       = kubernetes_service.mcp_gateway.spec[0].port[0].port
}

output "gateway_endpoint" {
  description = "Internal cluster endpoint for MCP Gateway"
  value       = "http://${kubernetes_service.mcp_gateway.metadata[0].name}.${kubernetes_service.mcp_gateway.metadata[0].namespace}.svc.cluster.local"
}

output "deployment_name" {
  description = "Name of the MCP Gateway deployment"
  value       = kubernetes_deployment.mcp_gateway.metadata[0].name
}

output "config_map_name" {
  description = "Name of the MCP Gateway configuration ConfigMap"
  value       = kubernetes_config_map.mcp_gateway_config.metadata[0].name
}

output "enabled_servers" {
  description = "List of enabled MCP servers"
  value       = keys(var.mcp_servers)
}

output "enabled_tools" {
  description = "List of enabled MCP tools"
  value       = var.enabled_tools
}