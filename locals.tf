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


    # The hostnames before the library. Both apps answer their old page URLs with a permanent
    # redirect into library.rainforest.tools and keep serving feeds, APIs and MCP here.
    {
      "calibre" = {
        hostname    = "calibre"
        service_url = module.personal-calibre.tunnel_service_url
        enable_auth = true
        type        = "docker"
      }
    },

    # library.rainforest.tools: one hostname, one app per path (see the library architecture).
    # The hall's catch-all owns the hostname's DNS record and Access application; every path
    # entry on it sets internal = true, so the hostname keeps one of each, and the tunnel emits
    # path rules before the catch-all whatever their key order.
    {
      "library" = {
        hostname    = "library"
        service_url = module.library-hall.tunnel_service_url
        enable_auth = true
        type        = "docker"
      }
      "library-books" = {
        hostname    = "library"
        service_url = module.personal-calibre.tunnel_service_url
        enable_auth = true
        type        = "docker"
        internal    = true
        # /opds answers with a redirect to /books/opds, under calibre's base path.
        path = "^/(books|opds)(/|$)"
      }
      "library-notebooks" = {
        hostname    = "library"
        service_url = module.personal-notebook.tunnel_service_url
        enable_auth = true
        type        = "docker"
        internal    = true
        path        = "^/notebooks(/|$)"
      }
      "library-reading-room" = {
        hostname    = "library"
        service_url = module.rss-manager.tunnel_service_url
        enable_auth = true
        type        = "docker"
        internal    = true
        path        = "^/(rack|kb)(/|$)"
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

    var.enable_personal_memories ? {
      "memories" = {
        hostname       = "memories"
        service_url    = module.personal-memories[0].tunnel_service_url
        enable_auth    = true
        type           = "docker"
        allowed_emails = ["ting1110001@gmail.com"]
      }
    } : {},

    var.enable_personal_memories ? {
      "memories-mcp-internal" = {
        hostname    = "memories-mcp-internal"
        service_url = module.personal-memories[0].tunnel_service_url
        enable_auth = false # The OAuth Worker sends the gateway secret; the app rejects calls without it
        type        = "docker"
        path        = "^/mcp$"
      }
    } : {},

    {
      "library-mcp-internal" = {
        hostname    = "library-mcp-internal"
        service_url = module.library-hall.tunnel_service_url
        enable_auth = false # The OAuth Worker sends the gateway secret; the app rejects calls without it
        type        = "docker"
        path        = "^/api/mcp$"
      }
    },

    {
      "personal-calibre-internal" = {
        hostname    = "personal-calibre-internal"
        service_url = module.personal-calibre.tunnel_service_url
        enable_auth = false # The OAuth Worker sends the gateway secret; the app rejects calls without it
        type        = "docker"
        # The Worker calls /books/mcp, under calibre's base path; /mcp redirects there.
        path = "^(/books)?/mcp$"
      }
    },

    var.enable_n8n_mcp ? {
      "n8n-mcp-internal" = {
        hostname    = "n8n-mcp-internal"
        service_url = "http://homelab-n8n.homelab.svc.cluster.local:5678"
        enable_auth = false # The OAuth Worker sends the n8n MCP token; n8n rejects calls without it
        type        = "kubernetes"
        path        = "^/mcp-server/http$"
      }
    } : {},

    {
      "docker-mcp-internal" = {
        hostname          = "docker-mcp-internal"
        service_url       = "http://host.docker.internal:3101" # launchd managed gateway (docker mcp gateway run)
        enable_auth       = true                               # The gateway itself runs --allow-unauthenticated
        type              = "docker"
        service_auth_only = true
        # The streaming transport's DNS-rebinding guard accepts only localhost/127.0.0.1
        # as Host. Without this rewrite cloudflared forwards the public hostname and the
        # gateway answers 403 "invalid Host header" — after OAuth has already succeeded.
        http_host_header = "localhost:3101"
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

    # pgadmin removed: it is disabled (enable_pgadmin = false) and never deployed,
    # but the entry kept publishing a DNS record and Zero Trust app for a service
    # that does not exist. Re-add this block if pgadmin is ever enabled.
    # obsidian-internal removed: the Docker MCP gateway now serves Obsidian tools.

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
        hostname           = "tp"
        service_url        = "https://homelab-teleport.homelab.svc.cluster.local:443"
        origin_server_name = var.teleport_direct_access ? "tp.${var.domain_suffix}" : ""
        no_tls_verify      = !var.teleport_direct_access
        enable_auth        = false # Teleport handles its own authentication
        type               = "kubernetes"
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