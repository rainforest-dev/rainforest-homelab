output "service_name" {
  description = "Name of the CoreDNS service"
  value       = helm_release.coredns.name
}

output "namespace" {
  description = "Namespace where CoreDNS is deployed"
  value       = helm_release.coredns.namespace
}

output "dns_server_ip" {
  description = "IP address of the DNS server"
  value       = var.tailscale_ip
}