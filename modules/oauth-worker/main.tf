# The OAuth Worker is deployed via Wrangler with name "homelab-oauth-gateway"
# Secrets are now managed by Terraform for automation

# Custom domain for the OAuth Worker
resource "cloudflare_workers_domain" "oauth_gateway" {
  account_id = var.cloudflare_account_id
  hostname   = "docker-mcp.${var.domain_suffix}"
  service    = "${var.project_name}-oauth-gateway"
  zone_id    = var.cloudflare_zone_id
}

# Service token credentials for docker-mcp-internal authentication (only if provided)
resource "cloudflare_workers_secret" "service_token_id" {
  count = var.service_token_client_id != "" ? 1 : 0

  account_id  = var.cloudflare_account_id
  script_name = "${var.project_name}-oauth-gateway"
  name        = "SERVICE_TOKEN_ID"
  secret_text = var.service_token_client_id
}

resource "cloudflare_workers_secret" "service_token_secret" {
  count = var.service_token_client_secret != "" ? 1 : 0

  account_id  = var.cloudflare_account_id
  script_name = "${var.project_name}-oauth-gateway"
  name        = "SERVICE_TOKEN_SECRET"
  secret_text = var.service_token_client_secret
}