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
      # loop-observatory — autonomous-task-loop dashboard (Astro SSR + Vue).
      # Runs as a host launchd service on the mini (PORT=3099), reached via
      # host.docker.internal like calibre-web. Zero Trust gated by allowed_emails.
      "loop-observatory" = {
        hostname    = "loop"
        service_url = "http://host.docker.internal:3099"
        enable_auth = true
        type        = "docker"
      }
    },

    {
      "calibre" = {
        hostname    = "calibre"
        service_url = module.personal-calibre.tunnel_service_url
        enable_auth = true
        type        = "docker"
      }
    },

    {
      "rss" = {
        hostname    = "rss"
        service_url = module.rss-manager.tunnel_service_url
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
      }
    },

    {
      "docker-mcp-internal" = {
        hostname    = "docker-mcp-internal"
        service_url = "http://host.docker.internal:3101" # launchd managed gateway (docker mcp gateway run)
        enable_auth = false                              # Auth handled by OAuth Worker layer
        type        = "docker"
      }
    },

    {
      whisper = {
        hostname    = "whisper"
        service_url = "http://host.docker.internal:9090" # container publishes 9090; :9000 is MinIO
        enable_auth = true                               # Protect with Zero Trust
        type        = "docker"
      }
    },

    {
      comfyui = {
        hostname    = "comfyui"
        service_url = "http://host.docker.internal:8000"
        enable_auth = true
        type        = "docker"
      }
    },

    {
      agy = {
        hostname    = "agy"
        service_url = "http://host.docker.internal:3000"
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

    # grafana-mcp removed: folded into the Docker MCP Gateway (default profile).
    # Grafana MCP tools now arrive via docker-mcp.rainforest.tools, not a separate host.

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

    {
      "bambii" = {
        hostname       = "bambii"
        service_url    = "http://host.docker.internal:9119"
        enable_auth    = true
        type           = "docker"
        allowed_emails = ["ting1110001@gmail.com"]
      }
    },

    var.enable_teleport ? {
      tp = {
        hostname    = "tp"
        service_url = "https://homelab-teleport.homelab.svc.cluster.local:443"
        enable_auth = false # Teleport handles its own authentication
        type        = "kubernetes"
      }
    } : {},

    # IoT / Raspberry Pi services — routed over LAN by the Mac Mini cloudflared.
    # Only expose services with genuine remote-access use cases.
    # Admin-only UIs (Pi-hole, Homebridge) stay internal; use Teleport SSH for those.
    {
      "homepage" = {
        hostname    = "homepage"
        service_url = "http://${var.raspberry_pi_ip}:8888"
        enable_auth = true
        type        = "iot"
      }
    },

    var.enable_homeassistant ? {
      "homeassistant" = {
        hostname       = "homeassistant"
        service_url    = "http://${var.raspberry_pi_ip}:8123"
        enable_auth    = false # HA has its own auth; Zero Trust breaks Google OAuth account linking
        type           = "iot"
        allowed_emails = ["ting1110001@gmail.com"]
      }
    } : {},

    var.enable_homeassistant ? {
      "music-assistant" = {
        hostname       = "music-assistant"
        service_url    = "http://${var.raspberry_pi_ip}:8095"
        enable_auth    = false # MA has its own auth; ZT blocks HA's WebSocket connection via tunnel
        type           = "iot"
        allowed_emails = ["ting1110001@gmail.com"]
      }
    } : {},

    # Observability UIs on Pi (K3s NodePort services)
    {
      "gfn" = {
        hostname    = "gfn"
        service_url = "http://${var.raspberry_pi_ip}:30080"
        enable_auth = true
        type        = "iot"
      }
    },

  )

  # Extract service lists for Cloudflare resources
  service_hostnames = keys(local.services)
  auth_enabled_services = [
    for name, config in local.services : name
    if config.enable_auth && length(var.allowed_email_domains) > 0
  ]
}