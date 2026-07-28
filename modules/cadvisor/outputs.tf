output "metrics_url" {
  description = "cAdvisor Prometheus metrics endpoint"
  value       = "http://host.docker.internal:${var.port}/metrics"
}

output "container_name" {
  value = docker_container.cadvisor.name
}
