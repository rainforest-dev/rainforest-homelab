data "cloudflare_zones" "domain" {
  filter {
    name = var.domain_suffix
  }
}

locals {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  fqdn    = "${var.hostname}.${var.domain_suffix}"
}

resource "docker_image" "app" {
  name         = var.image
  keep_locally = true
}

resource "docker_container" "app" {
  image   = docker_image.app.image_id
  name    = "${var.project_name}-memories-next"
  restart = "always"

  memory      = var.memory_limit_mb
  memory_swap = -1

  ports {
    internal = 3004
    external = var.external_port
    ip       = var.bind_ip
  }

  env = [
    "NODE_ENV=production",
    "MEMORIES_UI=inside-out",
    "MEMORIES_DATA_DIR=${var.data_dir}",
    "MEMORIES_NOTES_DIR=${var.notes_dir}",
    "MEMORIES_V2_DIR=${var.v2_dir}",
    "MEMORIES_OWNER=${var.owner_names}",
    "MEMORIES_OLLAMA_URL=${var.ollama_url}",
    "MEMORIES_PUBLIC_URL=https://${local.fqdn}",
    "MEMORIES_IDENTITIES=${var.identities}",
  ]

  volumes {
    container_path = var.data_dir
    host_path      = var.data_dir
    read_only      = true
  }

  volumes {
    container_path = var.photos_library_path
    host_path      = var.photos_library_path
    read_only      = true
  }

  volumes {
    container_path = var.notes_dir
    host_path      = var.notes_dir
    read_only      = true
  }

  volumes {
    container_path = var.v2_dir
    host_path      = var.v2_dir
    read_only      = false
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "environment"
    value = var.environment
  }
  labels {
    label = "service"
    value = "memories-next"
  }
}

resource "random_password" "tunnel_secret" {
  length  = 32
  special = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = var.cloudflare_account_id
  name       = "${var.project_name}-memories-next"
  secret     = base64encode(random_password.tunnel_secret.result)
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config {
    ingress_rule {
      hostname = local.fqdn
      service  = "http://host.docker.internal:${var.external_port}"
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "this" {
  zone_id = local.zone_id
  name    = var.hostname
  content = cloudflare_zero_trust_tunnel_cloudflared.this.cname
  type    = "CNAME"
  proxied = true
  comment = "Managed by Terraform - memories-next review tunnel"
}

resource "cloudflare_zero_trust_access_application" "this" {
  zone_id                   = local.zone_id
  name                      = "Memories-Next - ${var.project_name}"
  domain                    = local.fqdn
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = false
}

resource "cloudflare_zero_trust_access_policy" "two_people" {
  application_id = cloudflare_zero_trust_access_application.this.id
  zone_id        = local.zone_id
  name           = "Allow the two of us"
  precedence     = 1
  decision       = "allow"

  include {
    email = var.allowed_emails
  }
}

resource "docker_image" "cloudflared" {
  name         = "cloudflare/cloudflared:${var.cloudflared_version}"
  keep_locally = true
}

resource "docker_container" "cloudflared" {
  image   = docker_image.cloudflared.image_id
  name    = "${var.project_name}-memories-next-cloudflared"
  restart = "always"
  command = ["tunnel", "--no-autoupdate", "run"]

  env = ["TUNNEL_TOKEN=${cloudflare_zero_trust_tunnel_cloudflared.this.tunnel_token}"]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "service"
    value = "memories-next"
  }

  depends_on = [cloudflare_zero_trust_tunnel_cloudflared_config.this]
}
