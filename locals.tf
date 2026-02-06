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
      flowise = {
        hostname    = "flowise"
        service_url = "http://homelab-flowise.homelab.svc.cluster.local:3000"
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
      "docker-mcp-internal" = {
        hostname    = "docker-mcp-internal"
        service_url = module.docker_mcp_gateway.tunnel_service_url
        enable_auth = false # No auth needed for internal proxy route
        type        = "docker"
        internal    = true # Skip DNS record creation - OAuth Worker handles the domain
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
      pgadmin = {
        hostname    = "pgadmin"
        service_url = "http://homelab-pgadmin-pgadmin4.homelab.svc.cluster.local"
        enable_auth = true # Protect with Zero Trust
        type        = "kubernetes"
      }
    },

    var.enable_teleport ? {
      tp = {
        hostname    = "tp"
        service_url = "https://homelab-teleport.homelab.svc.cluster.local:443"
        enable_auth = true # Protect with Zero Trust
        type        = "kubernetes"
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