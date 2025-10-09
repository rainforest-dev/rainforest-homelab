output "tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

output "tunnel_cname" {
  description = "Cloudflare Tunnel CNAME"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.cname
}

output "zone_id" {
  description = "Cloudflare Zone ID"
  value       = local.zone_id
}

output "service_urls" {
  description = "Service URLs accessible via Cloudflare Tunnel"
  value = {
    homepage   = "https://homepage.${var.domain_suffix}"
    open_webui = "https://open-webui.${var.domain_suffix}"
    flowise    = "https://flowise.${var.domain_suffix}"
    n8n        = "https://n8n.${var.domain_suffix}"
    minio      = "https://minio.${var.domain_suffix}"
    s3         = "https://s3.${var.domain_suffix}"
  }
}

output "zero_trust_applications" {
  description = "Zero Trust application IDs"
  value = {
    for k, v in cloudflare_zero_trust_access_application.services : k => v.id
  }
}

output "zero_trust_policies" {
  description = "Zero Trust access policy IDs"
  value = {
    for k, v in cloudflare_zero_trust_access_policy.email_policy : k => v.id
  }
}

output "dns_records" {
  description = "DNS record IDs created for services"
  value = {
    for k, v in cloudflare_record.services : k => v.id
  }
}

output "manual_setup_required" {
  description = "WARNING: Manual setup required for service token policy"
  value = local.needs_manual_policy_setup ? {
    warning = "⚠️  MANUAL SETUP REQUIRED: Service token policy missing for docker-mcp-internal"
    application_id = try(cloudflare_zero_trust_access_application.services["docker-mcp-internal"].id, "N/A")
    instructions = <<-EOT

    🚨 ACTION REQUIRED: Create Service Token Policy

    The docker-mcp-internal Access Application exists but is missing the service token policy.
    This will cause 502 errors when the OAuth Worker tries to access the MCP Gateway.

    Steps to fix:
    1. Go to: https://dash.cloudflare.com/ → Zero Trust → Access → Applications
    2. Find: "Docker-Mcp-Internal - homelab" → Click "Edit"
    3. Go to: "Policies" tab → Click "Add a policy"
    4. Configure:
       - Name: "OAuth Worker Service Token"
       - Action: "Service Auth" (NOT "Allow")
       - Configure rules → Add include → Service Token
       - Select: "homelab-oauth-worker-service-token"
    5. Save policy → Save application

    After completing these steps, run 'terraform refresh' to update the state.

    EOT
  } : null
}

output "policy_check_status" {
  description = "Service token policy validation status"
  value = contains(keys(var.services), "docker-mcp-internal") && length(var.allowed_email_domains) > 0 ? {
    has_service_token_policy = local.has_service_token_policy
    total_policies           = local.policy_check_result.total_policies
  } : null
}