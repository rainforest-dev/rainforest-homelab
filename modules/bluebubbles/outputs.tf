output "server_url" {
  description = "BLUEBUBBLES_SERVER_URL for Hermes on this Mac"
  value       = "http://127.0.0.1:${var.port}"
}

output "hermes_env" {
  description = "Lines for ~/.hermes/.env"
  sensitive   = true
  value       = <<-EOT
    BLUEBUBBLES_SERVER_URL=http://127.0.0.1:${var.port}
    BLUEBUBBLES_PASSWORD=${var.server_password}
  EOT
}

output "installed" {
  description = "Changes when the app is reinstalled"
  value       = null_resource.install.id
}
