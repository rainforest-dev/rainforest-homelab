locals {
  # Collect service configurations from all enabled modules
  services = merge(
    # Homepage moved to rainforest-iot folder
    # Kubernetes services

    {
      "open-webui" = {
        hostname    = "open-webui"
        service_url = "http://open-webui.homelab.svc.cluster.local:80"
        enable_auth = true
        type        = "kubernetes"
      }
    },

    {
      n8n = {
        hostname    = "n8n"
        service_url = "http://homelab-n8n.homelab.svc.cluster.local:5678"
        enable_auth = true
        type        = "kubernetes"
      }
    },

    {
      minio = {
        hostname    = "minio"
        service_url = "http://homelab-minio-console.homelab.svc.cluster.local:9001"
        enable_auth = true
        type        = "kubernetes"
      }
    },

    {
      s3 = {
        hostname    = "s3"
        service_url = "http://homelab-minio.homelab.svc.cluster.local:9000"
        enable_auth = false # S3 API doesn't need Zero Trust auth
        type        = "kubernetes"
      }
    },

    {
      "calibre-web" = {
        hostname    = "calibre-web"
        service_url = "http://host.docker.internal:8083"
        enable_auth = true
        type        = "docker"
      }
    },

    {
      "personal-calibre-internal" = {
        hostname    = "personal-calibre-internal"
        service_url = module.personal-calibre.tunnel_service_url
        enable_auth = false # Auth handled by OAuth Worker layer
        type        = "docker"
        internal    = true  # DNS record skipped; only reachable via Cloudflare Tunnel
      }
    },

    {
      "docker-mcp-internal" = {
        hostname    = "docker-mcp-internal"
        service_url = module.docker_mcp_gateway.tunnel_service_url
        enable_auth = false # Auth handled by OAuth Worker layer
        internal    = true  # No public DNS record — only reachable via the OAuth Worker
        type        = "docker"
      }
    },

    {
      whisper = {
        hostname    = "whisper"
        service_url = "http://host.docker.internal:9000"
        enable_auth = true # Protect with Zero Trust
        type        = "docker"
      }
    },

    {
      comfyui = {
        hostname    = "comfyui"
        service_url = "http://host.docker.internal:8188"
        enable_auth = true
        type        = "docker"
      }
    },

    var.enable_comfyui_adapter ? {
      "image-gen" = {
        hostname    = "image-gen"
        service_url = "http://host.docker.internal:7860"
        enable_auth = false
        type        = "docker"
      }
    } : {},

    var.grafana_mcp_api_key != "" ? {
      "grafana-mcp" = {
        hostname    = "grafana-mcp"
        service_url = "http://host.docker.internal:8765"
        enable_auth = true
        type        = "docker"
      }
    } : {},

    {
      pgadmin = {
        hostname    = "pgadmin"
        service_url = "http://homelab-pgadmin-pgadmin4.homelab.svc.cluster.local"
        enable_auth = true # Protect with Zero Trust
        type        = "kubernetes"
      }
    },

    var.obsidian_api_key != "" ? {
      "obsidian-internal" = {
        hostname    = "obsidian-internal"
        service_url = module.obsidian_mcp[0].service_url
        enable_auth = false # Auth handled by OAuth Worker layer
        type        = "docker"
      }
    } : {},

    var.enable_teleport ? {
      tp = {
        hostname    = "tp"
        service_url = "https://homelab-teleport.homelab.svc.cluster.local:443"
        enable_auth = false # Teleport handles its own authentication
        type        = "kubernetes"
      }
    } : {},

    var.obsidian_api_key != "" ? {
      obsidian = {
        hostname    = "obsidian"
        service_url = module.obsidian_mcp[0].service_url
        enable_auth = true # Protect with Zero Trust
        type        = "docker"
      }
    } : {},

    # IoT / Raspberry Pi services — routed over LAN by the Mac Mini cloudflared.
    # Only expose services with genuine remote-access use cases.
    # Admin-only UIs (Pi-hole, Homebridge) stay internal; use Teleport SSH for those.
    var.enable_homeassistant ? {
      "homeassistant" = {
        hostname    = "homeassistant"
        service_url = "http://${var.raspberry_pi_ip}:8123"
        enable_auth = true # Zero Trust email auth + HA's own auth = two layers
        type        = "iot"
      }
    } : {},

  )

  # Extract service lists for Cloudflare resources
  service_hostnames = keys(local.services)
  auth_enabled_services = [
    for name, config in local.services : name
    if config.enable_auth && length(var.allowed_email_domains) > 0
  ]
}