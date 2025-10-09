# Provider configurations inherited from root module

# Get the zone ID for the domain
data "cloudflare_zones" "domain" {
  filter {
    name = var.domain_suffix
  }
}

locals {
  zone_id = data.cloudflare_zones.domain.zones[0].id
}

# Create Cloudflare Zero Trust Tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id = var.cloudflare_account_id
  name       = "${var.project_name}-tunnel"
  secret     = base64encode(random_password.tunnel_secret.result)
}

resource "random_password" "tunnel_secret" {
  length  = 32
  special = true
}

# Create tunnel configuration for cloudflared
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id

  config {
    warp_routing {
      enabled = false
    }

    origin_request {
      connect_timeout          = "1m0s"
      tls_timeout              = "1m0s"
      tcp_keep_alive           = "1m0s"
      no_happy_eyeballs        = false
      keep_alive_connections   = 1024
      keep_alive_timeout       = "1m30s"
      http_host_header         = ""
      origin_server_name       = ""
      ca_pool                  = ""
      no_tls_verify            = false
      disable_chunked_encoding = false
    }

    # Dynamic ingress rules from service configuration
    dynamic "ingress_rule" {
      for_each = var.services
      content {
        hostname = "${ingress_rule.value.hostname}.${var.domain_suffix}"
        service  = ingress_rule.value.service_url
      }
    }

    # Catch-all rule (required)
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# Create DNS records for each service (exclude internal services)
resource "cloudflare_record" "services" {
  for_each = {
    for name, config in var.services : name => config
    if !lookup(config, "internal", false) # Skip services marked as internal
  }

  zone_id = local.zone_id
  name    = each.value.hostname
  content = cloudflare_zero_trust_tunnel_cloudflared.homelab.cname
  type    = "CNAME"
  proxied = true
  comment = "Managed by Terraform - Cloudflare Tunnel"
}

# Create Zero Trust Application for each service (only if email domains are configured)
resource "cloudflare_zero_trust_access_application" "services" {
  for_each = length(var.allowed_email_domains) > 0 ? {
    for name, config in var.services : name => config
    if config.enable_auth
  } : {}

  zone_id          = local.zone_id
  name             = "${title(each.value.hostname)} - ${var.project_name}"
  domain           = "${each.value.hostname}.${var.domain_suffix}"
  type             = "self_hosted"
  session_duration = "24h"

  # Enable automatic HTTPS
  auto_redirect_to_identity = false

  # CORS settings for modern web apps
  cors_headers {
    allowed_methods   = ["GET", "POST", "OPTIONS", "PUT", "DELETE"]
    allowed_origins   = ["https://${each.value.hostname}.${var.domain_suffix}"]
    allow_credentials = true
    max_age           = 86400
  }
}

# Create Zero Trust Access Policy - Email authentication
resource "cloudflare_zero_trust_access_policy" "email_policy" {
  for_each = length(var.allowed_email_domains) > 0 ? {
    for name, config in var.services : name => config
    if config.enable_auth
  } : {}

  application_id = cloudflare_zero_trust_access_application.services[each.key].id
  zone_id        = local.zone_id
  name           = "Allow ${each.key} access"
  precedence     = 1
  decision       = "allow"

  # Single include block with email authentication methods
  # Arrays create OR logic within the block - any email from domain OR any individual email
  include {
    email_domain = length(var.allowed_email_domains) > 0 ? var.allowed_email_domains : null
    email        = length(var.allowed_emails) > 0 ? var.allowed_emails : null
  }

}

# NOTE: Service Token policies for docker-mcp-internal CANNOT be automated
#
# Cloudflare Limitations:
# 1. Service token policies use Cloudflare's "reusable policy" system
# 2. Reusable policies cannot be created/managed via standard API endpoints
# 3. Terraform provider doesn't support service_token in include blocks (returns error 12130)
#
# Manual Setup Required (One-Time):
# - Create policy in Dashboard: Zero Trust → Access → Applications → docker-mcp-internal
# - Policy Type: "Service Auth" (decision: non_identity)
# - Include: Select your service token
#
# Benefits of Manual Setup:
# ✅ Reusable policy survives Access Application recreation
# ✅ Terraform validation below detects if policy is missing
# ✅ Once created, persists across all infrastructure changes

# Fetch all policies for the docker-mcp-internal application to check for service token policy
data "external" "docker_mcp_internal_policies" {
  count = length(var.allowed_email_domains) > 0 && contains(keys(var.services), "docker-mcp-internal") ? 1 : 0

  program = ["bash", "-c", <<-EOT
    set -e
    APP_ID="${cloudflare_zero_trust_access_application.services["docker-mcp-internal"].id}"
    ACCOUNT_ID="${var.cloudflare_account_id}"

    # Fetch policies from Cloudflare API
    RESPONSE=$(curl -s "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/apps/$APP_ID/policies" \
      -H "Authorization: Bearer ${var.cloudflare_api_token}")

    # Check if response is valid
    if [ -z "$RESPONSE" ] || [ "$RESPONSE" = "null" ]; then
      echo '{"total_policies":"0","has_service_token_policy":"false","error":"API returned null or empty response"}'
      exit 0
    fi

    # Check for API errors
    SUCCESS=$(echo "$RESPONSE" | jq -r '.success // false')
    if [ "$SUCCESS" != "true" ]; then
      ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message // "Unknown API error"')
      echo "{\"total_policies\":\"0\",\"has_service_token_policy\":\"false\",\"error\":\"$ERROR_MSG\"}"
      exit 0
    fi

    # Extract policy count and check for service token policy
    TOTAL=$(echo "$RESPONSE" | jq -r '.result | length // 0')
    HAS_SERVICE_TOKEN=$(echo "$RESPONSE" | jq -r '[.result[] | select(.decision == "non_identity")] | length > 0')

    # Return as JSON for Terraform
    echo "{\"total_policies\":\"$TOTAL\",\"has_service_token_policy\":\"$HAS_SERVICE_TOKEN\"}"
  EOT
  ]

  depends_on = [
    cloudflare_zero_trust_access_policy.email_policy
  ]
}

# Check if service token policy exists
locals {
  policy_check_result = length(var.allowed_email_domains) > 0 && contains(keys(var.services), "docker-mcp-internal") ? (
    data.external.docker_mcp_internal_policies[0].result
  ) : { total_policies = "0", has_service_token_policy = "false" }

  has_service_token_policy = local.policy_check_result.has_service_token_policy == "true"

  # Determine if manual setup warning should be shown
  needs_manual_policy_setup = (
    length(var.allowed_email_domains) > 0 &&
    contains(keys(var.services), "docker-mcp-internal") &&
    !local.has_service_token_policy
  )
}

# Create Kubernetes secret for tunnel credentials
resource "kubectl_manifest" "tunnel_credentials" {
  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-tunnel-credentials
  namespace: ${var.kubernetes_namespace}
type: Opaque
stringData:
  credentials.json: |
    {
      "AccountTag": "${var.cloudflare_account_id}",
      "TunnelSecret": "${base64encode(random_password.tunnel_secret.result)}",
      "TunnelID": "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}"
    }
YAML
}

# Deploy cloudflared as a Kubernetes deployment
resource "kubectl_manifest" "cloudflared_deployment" {
  depends_on = [kubectl_manifest.tunnel_credentials]

  yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: ${var.kubernetes_namespace}
  labels:
    app: cloudflared
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
        - tunnel
        - --config
        - /etc/cloudflared/config/config.yaml
        - run
        livenessProbe:
          httpGet:
            path: /ready
            port: 2000
          failureThreshold: 1
          initialDelaySeconds: 10
          periodSeconds: 10
        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared/config
          readOnly: true
        - name: creds
          mountPath: /etc/cloudflared/creds
          readOnly: true
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
      volumes:
      - name: creds
        secret:
          secretName: cloudflare-tunnel-credentials
      - name: config
        configMap:
          name: cloudflared-config
          items:
          - key: config.yaml
            path: config.yaml
YAML
}

# Create ConfigMap for cloudflared configuration
resource "kubectl_manifest" "cloudflared_config" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: ${var.kubernetes_namespace}
data:
  config.yaml: |
    tunnel: ${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}
    credentials-file: /etc/cloudflared/creds/credentials.json
    metrics: 0.0.0.0:2000
    no-autoupdate: true
    
    ingress:
%{for name, config in var.services~}
      - hostname: ${config.hostname}.${var.domain_suffix}
        service: ${config.service_url}
%{endfor~}
      - service: http_status:404
YAML
}
