output "wetty_deployment_id" {
  description = "The ID of the Wetty deployment resource"
  value       = kubectl_manifest.wetty_deployment.id
}

output "wetty_service_id" {
  description = "The ID of the Wetty service resource"
  value       = kubectl_manifest.wetty_service.id
}

output "service_name" {
  description = "Name of the Wetty service"
  value       = "${var.project_name}-wetty"
}

output "namespace" {
  description = "Kubernetes namespace where Wetty is deployed"
  value       = var.namespace
}

output "service_url" {
  description = "Internal service URL for Wetty (kubectl port-forward access)"
  value       = "http://localhost:${var.wetty_port}"
}

output "port_forward_command" {
  description = "Command to access Wetty via kubectl port-forward"
  value       = "kubectl port-forward -n ${var.namespace} service/${var.project_name}-wetty ${var.wetty_port}:${var.wetty_port}"
}