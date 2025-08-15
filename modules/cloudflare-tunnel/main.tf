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

# Create Cloudflare Tunnel
resource "cloudflare_tunnel" "homelab" {
  account_id = var.cloudflare_account_id
  name       = "${var.project_name}-tunnel"
  secret     = base64encode(random_password.tunnel_secret.result)
}

resource "random_password" "tunnel_secret" {
  length  = 32
  special = true
}

# Create tunnel token for cloudflared
resource "cloudflare_tunnel_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.homelab.id

  config {
    warp_routing {
      enabled = false
    }

    origin_request {
      connect_timeout          = "1m0s"
      tls_timeout             = "1m0s"
      tcp_keep_alive          = "1m0s"
      no_happy_eyeballs       = false
      keep_alive_connections  = 1024
      keep_alive_timeout      = "1m30s"
      http_host_header        = ""
      origin_server_name      = ""
      ca_pool                 = ""
      no_tls_verify           = false
      disable_chunked_encoding = false
    }

    ingress_rule {
      hostname = "homepage.${var.domain_suffix}"
      service  = "http://homelab-homepage.homelab.svc.cluster.local:3000"
    }

    ingress_rule {
      hostname = "open-webui.${var.domain_suffix}"
      service  = "http://open-webui.homelab.svc.cluster.local:80"
    }

    ingress_rule {
      hostname = "flowise.${var.domain_suffix}"
      service  = "http://homelab-flowise.homelab.svc.cluster.local:3000"
    }

    ingress_rule {
      hostname = "n8n.${var.domain_suffix}"
      service  = "http://homelab-n8n.homelab.svc.cluster.local:80"
    }

    # Catch-all rule (required)
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# Create DNS records for each service
resource "cloudflare_record" "services" {
  for_each = toset([
    "homepage",
    "open-webui", 
    "flowise",
    "n8n"
  ])

  zone_id = local.zone_id
  name    = each.value
  content = cloudflare_tunnel.homelab.cname
  type    = "CNAME"
  proxied = true
  comment = "Managed by Terraform - Cloudflare Tunnel"
}

# Create Zero Trust Application for each service (only if email domains are configured)
resource "cloudflare_access_application" "services" {
  for_each = length(var.allowed_email_domains) > 0 ? toset([
    "homepage",
    "open-webui",
    "flowise", 
    "n8n"
  ]) : toset([])

  zone_id          = local.zone_id
  name             = "${title(each.value)} - ${var.project_name}"
  domain           = "${each.value}.${var.domain_suffix}"
  type             = "self_hosted"
  session_duration = "24h"

  # Enable automatic HTTPS
  auto_redirect_to_identity = false
  
  # CORS settings for modern web apps
  cors_headers {
    allowed_methods = ["GET", "POST", "OPTIONS", "PUT", "DELETE"]
    allowed_origins = ["https://${each.value}.${var.domain_suffix}"]
    allow_credentials = true
    max_age = 86400
  }
}

# Create Zero Trust Access Policy - Email verification (only if applications exist)
resource "cloudflare_access_policy" "email_policy" {
  for_each = cloudflare_access_application.services

  application_id = each.value.id
  zone_id        = local.zone_id
  name           = "Allow ${each.key} access"
  precedence     = 1
  decision       = "allow"

  include {
    email_domain = var.allowed_email_domains
  }

  # Optional: Add email list for specific users
  dynamic "include" {
    for_each = length(var.allowed_emails) > 0 ? [1] : []
    content {
      email = var.allowed_emails
    }
  }
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
      "TunnelID": "${cloudflare_tunnel.homelab.id}"
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
  replicas: 2
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
    tunnel: ${cloudflare_tunnel.homelab.id}
    credentials-file: /etc/cloudflared/creds/credentials.json
    metrics: 0.0.0.0:2000
    no-autoupdate: true
YAML
}