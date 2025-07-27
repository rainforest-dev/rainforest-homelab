# Standard outputs
output "resource_id" {
  description = "The ID of the n8n Helm release"
  value       = helm_release.n8n.id
}

output "service_url" {
  description = "Service URL for n8n"
  value       = "https://n8n.k8s.orb.local"
}

output "service_name" {
  description = "Name of the n8n service"
  value       = helm_release.n8n.name
}

output "namespace" {
  description = "Kubernetes namespace where n8n is deployed"
  value       = helm_release.n8n.namespace
}

# Service-specific outputs
output "helm_release_name" {
  description = "Helm release name for n8n"
  value       = helm_release.n8n.name
}

output "helm_chart" {
  description = "Helm chart used for n8n"
  value       = helm_release.n8n.chart
}

output "helm_repository" {
  description = "Helm repository URL for n8n chart"
  value       = helm_release.n8n.repository
}

output "helm_version" {
  description = "Helm chart version for n8n"
  value       = helm_release.n8n.version
}

output "chart_repository" {
  description = "Chart repository URL from variables"
  value       = var.chart_repository
}

output "chart_name" {
  description = "Chart name from variables"
  value       = var.chart_name
}

output "chart_version" {
  description = "Chart version from variables"
  value       = var.chart_version
}