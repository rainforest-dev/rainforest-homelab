data "cloudflare_zones" "domain" {
  filter {
    name = var.domain_suffix
  }
}

locals {
  zone_id    = data.cloudflare_zones.domain.zones[0].id
  fqdn       = "${var.hostname}.${var.domain_suffix}"
  name       = "${var.project_name}-vercel-board"
  image_name = "${var.project_name}/vercel-board:local"
  module_dir = abspath(path.module)
  build_trigger = join(":", [
    var.board_user,
    filemd5("${path.module}/Dockerfile"),
    filemd5("${path.module}/entrypoint.mjs"),
    filemd5("${path.module}/package.json"),
    filemd5("${path.module}/package-lock.json"),
  ])
}

resource "null_resource" "build" {
  triggers = {
    build_trigger = local.build_trigger
  }

  provisioner "local-exec" {
    command = "docker build --build-arg BOARD_USER='${var.board_user}' -t '${local.image_name}' '${local.module_dir}'"
  }
}

resource "docker_image" "vercel_board" {
  name         = local.image_name
  keep_locally = true

  depends_on = [null_resource.build]
}

resource "docker_volume" "data" {
  name = "${local.name}-data"

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "service"
    value = "vercel-board"
  }
  labels {
    label = "environment"
    value = var.environment
  }
}

resource "docker_network" "board" {
  name   = local.name
  driver = "bridge"

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "service"
    value = "vercel-board"
  }
}

resource "docker_container" "vercel_board" {
  image   = docker_image.vercel_board.name
  name    = local.name
  restart = "always"

  memory      = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (can(regex("Gi", var.memory_limit)) ? 1024 : 1)
  memory_swap = -1

  networks_advanced {
    name = docker_network.board.name
  }

  ports {
    internal = 4101
    external = var.api_port
    ip       = "127.0.0.1"
  }

  env = [
    "BOARD_PORT=${var.api_port}",
    "BOARD_ALLOW_HOSTS=${local.fqdn}",
  ]

  volumes {
    container_path = "/data"
    volume_name    = docker_volume.data.name
  }

  volumes {
    container_path = "/home/board/.config/board/local"
    host_path      = var.token_dir
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "service"
    value = "vercel-board"
  }
  labels {
    label = "environment"
    value = var.environment
  }

  lifecycle {
    replace_triggered_by = [null_resource.build]
  }

  depends_on = [docker_image.vercel_board]
}

resource "random_password" "tunnel_secret" {
  length  = 32
  special = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "board" {
  account_id = var.cloudflare_account_id
  name       = local.name
  secret     = base64encode(random_password.tunnel_secret.result)
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "board" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.board.id

  config {
    ingress_rule {
      hostname = local.fqdn
      service  = "http://${docker_container.vercel_board.name}:4748"
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "board" {
  zone_id = local.zone_id
  name    = var.hostname
  content = cloudflare_zero_trust_tunnel_cloudflared.board.cname
  type    = "CNAME"
  proxied = true
  comment = "Managed by Terraform - vercel-board tunnel"
}

resource "cloudflare_zero_trust_access_application" "board" {
  zone_id                   = local.zone_id
  name                      = "Vercel Board - ${var.project_name}"
  domain                    = local.fqdn
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = false
}

resource "cloudflare_zero_trust_access_policy" "owner" {
  application_id = cloudflare_zero_trust_access_application.board.id
  zone_id        = local.zone_id
  name           = "Allow the board owner"
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
  name    = "${local.name}-cloudflared"
  restart = "always"
  command = ["tunnel", "--no-autoupdate", "run"]

  env = ["TUNNEL_TOKEN=${cloudflare_zero_trust_tunnel_cloudflared.board.tunnel_token}"]

  networks_advanced {
    name = docker_network.board.name
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "service"
    value = "vercel-board"
  }

  depends_on = [cloudflare_zero_trust_tunnel_cloudflared_config.board]
}
