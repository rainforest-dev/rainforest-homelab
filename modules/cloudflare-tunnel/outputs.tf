output "tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

output "tunnel_cname" {
  description = "Cloudflare Tunnel CNAME"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.cname
}

output "service_urls" {
  description = "Service URLs accessible via Cloudflare Tunnel"
  value = {
    homepage   = "https://homepage.${var.domain_suffix}"
    open_webui = "https://open-webui.${var.domain_suffix}"
    flowise    = "https://flowise.${var.domain_suffix}"
    n8n        = "https://n8n.${var.domain_suffix}"
  }
}

output "zero_trust_applications" {
  description = "Zero Trust application IDs"
  value = {
    for k, v in cloudflare_zero_trust_access_application.services : k => v.id
  }
}