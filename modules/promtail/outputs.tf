output "release_name" {
  description = "Promtail Helm release name"
  value       = helm_release.promtail.name
}

output "namespace" {
  description = "Promtail namespace"
  value       = helm_release.promtail.namespace
}

output "loki_url" {
  description = "Configured Loki endpoint"
  value       = var.loki_url
}
