# Standard outputs
output "resource_id" {
  description = "The ID of the Teleport Agent Helm release"
  value       = helm_release.teleport.id
}

output "service_url" {
  description = "Service URL for Teleport Agent (internal cluster agent, no direct web access)"
  value       = "internal-cluster-agent"
}

output "service_name" {
  description = "Name of the Teleport Agent service"
  value       = helm_release.teleport.name
}

output "namespace" {
  description = "Kubernetes namespace where Teleport Agent is deployed"
  value       = helm_release.teleport.namespace
}

# Service-specific outputs
output "helm_release_name" {
  description = "Helm release name for Teleport Agent"
  value       = helm_release.teleport.name
}

output "helm_chart" {
  description = "Helm chart used for Teleport Agent"
  value       = helm_release.teleport.chart
}

output "helm_repository" {
  description = "Helm repository URL for Teleport chart"
  value       = helm_release.teleport.repository
}

output "helm_version" {
  description = "Helm chart version for Teleport Agent"
  value       = helm_release.teleport.version
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

output "release_name" {
  description = "Helm release name from variables"
  value       = var.release_name
}

output "values_file_path" {
  description = "Path to the Helm values file"
  value       = var.values_file_path
}