# Standard outputs
output "resource_id" {
  description = "The ID of the Homepage Helm release"
  value       = helm_release.homepage.id
}

output "service_url" {
  description = "Service URL for Homepage"
  value       = "https://homepage.${var.domain_suffix}"
}

output "service_name" {
  description = "Name of the Homepage service"
  value       = helm_release.homepage.name
}

output "namespace" {
  description = "Kubernetes namespace where Homepage is deployed"
  value       = helm_release.homepage.namespace
}

# Service-specific outputs
output "helm_release_name" {
  description = "Helm release name for Homepage"
  value       = helm_release.homepage.name
}

output "helm_chart" {
  description = "Helm chart used for Homepage"
  value       = helm_release.homepage.chart
}

output "helm_repository" {
  description = "Helm repository URL for Homepage chart"
  value       = helm_release.homepage.repository
}

output "helm_version" {
  description = "Helm chart version for Homepage"
  value       = helm_release.homepage.version
}

output "chart_repository" {
  description = "Chart repository URL from variables"
  value       = var.chart_repository
}

output "chart_name" {
  description = "Chart name from variables"
  value       = var.chart_name
}

output "values_file_path" {
  description = "Path to the Helm values file"
  value       = var.values_file_path
}
