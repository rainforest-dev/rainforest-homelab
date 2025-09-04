output "service_name" {
  description = "Name of the Wetty service"
  value       = kubernetes_service.wetty.metadata[0].name
}

output "service_namespace" {
  description = "Namespace of the Wetty service"
  value       = kubernetes_service.wetty.metadata[0].namespace
}

output "node_port" {
  description = "NodePort for Tailscale access"
  value       = kubernetes_service.wetty.spec[0].port[0].node_port
}

output "service_port" {
  description = "Service port"
  value       = kubernetes_service.wetty.spec[0].port[0].port
}