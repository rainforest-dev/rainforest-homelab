# The OAuth Worker is deployed via Wrangler with name "homelab-oauth-gateway" 
# It has its own KV namespace and secrets configured via Wrangler, except
# MEMORIES_GATEWAY_SECRET, CALIBRE_GATEWAY_SECRET, LIBRARY_GATEWAY_SECRET and N8N_MCP_TOKEN, which Terraform
# owns so each matches its backend.

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

resource "cloudflare_workers_domain" "n8n_mcp_gateway" {
  count      = var.enable_n8n_mcp ? 1 : 0
  account_id = var.cloudflare_account_id
  hostname   = "n8n-mcp.${var.domain_suffix}"
  service    = "${var.project_name}-oauth-gateway"
  zone_id    = var.cloudflare_zone_id
}

resource "cloudflare_workers_secret" "calibre_gateway" {
  account_id  = var.cloudflare_account_id
  script_name = "${var.project_name}-oauth-gateway"
  name        = "CALIBRE_GATEWAY_SECRET"
  secret_text = var.calibre_gateway_secret
}

resource "cloudflare_workers_domain" "library_mcp_gateway" {
  account_id = var.cloudflare_account_id
  hostname   = "library-mcp.${var.domain_suffix}"
  service    = "${var.project_name}-oauth-gateway"
  zone_id    = var.cloudflare_zone_id
}

resource "cloudflare_workers_secret" "library_gateway" {
  account_id  = var.cloudflare_account_id
  script_name = "${var.project_name}-oauth-gateway"
  name        = "LIBRARY_GATEWAY_SECRET"
  secret_text = var.library_gateway_secret
}

# The n8n MCP access token (n8n → Settings → Instance-level MCP). The Worker sends it as
# "Authorization: Bearer <token>" to n8n's /mcp-server/http.
resource "cloudflare_workers_secret" "n8n_mcp_token" {
  count       = var.enable_n8n_mcp ? 1 : 0
  account_id  = var.cloudflare_account_id
  script_name = "${var.project_name}-oauth-gateway"
  name        = "N8N_MCP_TOKEN"
  secret_text = var.n8n_mcp_token
}
