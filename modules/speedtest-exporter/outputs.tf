output "metrics_url" {
  description = "Prometheus metrics endpoint"
  value       = "http://host.docker.internal:${var.port}/metrics"
}
