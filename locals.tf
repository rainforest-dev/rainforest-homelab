locals {
  # Collect service configurations from all enabled modules
  services = merge(
    # Kubernetes services
    var.enable_homepage ? {
      homepage = {
        hostname    = "homepage"
        service_url = "http://homelab-homepage.homelab.svc.cluster.local:3000"
        enable_auth = true
        type        = "kubernetes"
      }
    } : {},

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
        service_url = "http://homelab-n8n.homelab.svc.cluster.local:80"
        enable_auth = true
        type        = "kubernetes"
      }
    },

    var.enable_minio ? {
      minio = {
        hostname    = "minio"
        service_url = "http://homelab-minio-console.homelab.svc.cluster.local:9001"
        enable_auth = true
        type        = "kubernetes"
      }
    } : {},

    var.enable_minio ? {
      s3 = {
        hostname    = "s3"
        service_url = "http://homelab-minio.homelab.svc.cluster.local:9000"
        enable_auth = false # S3 API doesn't need Zero Trust auth
        type        = "kubernetes"
      }
    } : {},

    var.enable_calibre_web ? {
      "calibre-web" = {
        hostname    = "calibre-web"
        service_url = "http://host.docker.internal:8083"
        enable_auth = true
        type        = "docker"
      }
    } : {},

    var.enable_docker_mcp_gateway ? {
      "docker-mcp" = {
        hostname    = "docker-mcp"
        service_url = module.docker_mcp_gateway[0].tunnel_service_url
        enable_auth = true
        type        = "docker"
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