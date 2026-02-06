output "service_name" {
  description = "Name of the Teleport service"
  value       = helm_release.teleport.name
}

output "namespace" {
  description = "Namespace where Teleport is deployed"
  value       = var.namespace
}

output "web_service_url" {
  description = "Internal Kubernetes service URL for Teleport web UI"
  value       = "http://${kubernetes_service.teleport_web.metadata[0].name}.${var.namespace}.svc.cluster.local:3080"
}

output "public_url" {
  description = "Public URL for Teleport access"
  value       = "https://${var.public_hostname}"
}

output "admin_token" {
  description = "Initial admin invitation token (keep secret!)"
  value       = random_password.teleport_auth_token.result
  sensitive   = true
}

output "cluster_name" {
  description = "Teleport cluster name"
  value       = var.public_hostname
}

output "kubernetes_cluster_name" {
  description = "Name of the Kubernetes cluster configured for access"
  value       = var.kubernetes_cluster_name
}

output "connection_instructions" {
  description = "Instructions for connecting to Teleport"
  value       = <<-EOT
    Teleport is now deployed! Here's how to get started:

    1. Web UI: https://${var.public_hostname}
    2. Create admin user:
       kubectl exec -n ${var.namespace} -it deploy/${var.project_name}-teleport-auth -- tctl users add admin --roles=editor,access --logins=root

    3. Install tsh client:
       brew install teleport

    4. Login via CLI:
       tsh login --proxy=${var.public_hostname}:443 --user=admin

    5. Access Kubernetes:
       tsh kube login ${var.kubernetes_cluster_name}

    For more info: https://goteleport.com/docs/
  EOT
}
