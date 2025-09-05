# Standard module outputs following homelab patterns

output "resource_id" {
  description = "Docker MCP Gateway deployment ID"
  value       = kubernetes_deployment.docker_mcp_gateway.metadata[0].uid
}

output "service_name" {
  description = "Docker MCP Gateway service name"
  value       = kubernetes_service.docker_mcp_gateway.metadata[0].name
}

output "service_url" {
  description = "Docker MCP Gateway service URL for internal cluster access"
  value       = "http://${kubernetes_service.docker_mcp_gateway.metadata[0].name}.${var.namespace}.svc.cluster.local:${var.port}"
}

output "namespace" {
  description = "Kubernetes namespace where Docker MCP Gateway is deployed"
  value       = var.namespace
}

# External access outputs

output "external_url" {
  description = "External URL for Docker MCP Gateway (when Cloudflare Tunnel is enabled)"
  value       = var.enable_cloudflare_tunnel && var.domain_suffix != "" ? "https://${var.tunnel_hostname}.${var.domain_suffix}" : null
}

output "tunnel_hostname" {
  description = "Hostname used for Cloudflare Tunnel routing"
  value       = var.tunnel_hostname
}

# Service discovery outputs

output "cluster_ip" {
  description = "Cluster IP of the Docker MCP Gateway service"
  value       = kubernetes_service.docker_mcp_gateway.spec[0].cluster_ip
}

output "port" {
  description = "Port on which Docker MCP Gateway is listening"
  value       = var.port
}

# Security and monitoring outputs

output "service_account_name" {
  description = "Service account name used by Docker MCP Gateway"
  value       = kubernetes_service_account.docker_mcp_gateway.metadata[0].name
}

output "config_map_name" {
  description = "Configuration map name for Docker MCP Gateway"
  value       = kubernetes_config_map.docker_mcp_config.metadata[0].name
}

output "metrics_url" {
  description = "Metrics endpoint URL (when metrics are enabled)"
  value       = var.enable_metrics ? "http://${kubernetes_service.docker_mcp_gateway.metadata[0].name}.${var.namespace}.svc.cluster.local:${var.metrics_port}/metrics" : null
}

# Deployment status outputs

output "deployment_name" {
  description = "Docker MCP Gateway deployment name"
  value       = kubernetes_deployment.docker_mcp_gateway.metadata[0].name
}

output "replicas" {
  description = "Number of replicas configured for Docker MCP Gateway"
  value       = var.replicas
}