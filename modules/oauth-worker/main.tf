# The OAuth Worker is deployed via Wrangler with name "homelab-oauth-gateway" 
# It has its own KV namespace and secrets configured via Wrangler
# We just need to create the custom domain binding

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

