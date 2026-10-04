# The OAuth Worker is deployed via Wrangler with name "homelab-oauth-gateway" 
# It has its own KV namespace and secrets configured via Wrangler, except
# MEMORIES_GATEWAY_SECRET and CALIBRE_GATEWAY_SECRET, which Terraform owns so each
# matches its container.

# Custom domains for the OAuth Worker
resource "cloudflare_workers_domain" "oauth_gateway" {
  account_id = var.cloudflare_account_id
  hostname   = "docker-mcp.${var.domain_suffix}"
  service    = "${var.project_name}-oauth-gateway"
  zone_id    = var.cloudflare_zone_id
}

resource "cloudflare_workers_domain" "calibre_mcp_gateway" {
  account_id = var.cloudflare_account_id
  hostname   = "calibre-mcp.${var.domain_suffix}"
  service    = "${var.project_name}-oauth-gateway"
  zone_id    = var.cloudflare_zone_id
}

resource "cloudflare_workers_domain" "memories_mcp_gateway" {
  count      = var.enable_memories_mcp ? 1 : 0
  account_id = var.cloudflare_account_id
  hostname   = "memories-mcp.${var.domain_suffix}"
  service    = "${var.project_name}-oauth-gateway"
  zone_id    = var.cloudflare_zone_id
}

# `wrangler deploy` keeps existing secrets, so a Terraform-managed one survives redeploys.
resource "cloudflare_workers_secret" "memories_gateway" {
  count       = var.enable_memories_mcp ? 1 : 0
  account_id  = var.cloudflare_account_id
  script_name = "${var.project_name}-oauth-gateway"
  name        = "MEMORIES_GATEWAY_SECRET"
  secret_text = var.memories_gateway_secret
}

resource "cloudflare_workers_secret" "calibre_gateway" {
  account_id  = var.cloudflare_account_id
  script_name = "${var.project_name}-oauth-gateway"
  name        = "CALIBRE_GATEWAY_SECRET"
  secret_text = var.calibre_gateway_secret
}
