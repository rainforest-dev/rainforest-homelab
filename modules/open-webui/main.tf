# ConfigMap for MCPO configuration
resource "kubernetes_config_map" "mcpo_config" {
  count = var.mcpo_enabled ? 1 : 0

  metadata {
    name      = "${var.project_name}-open-webui-mcpo-config"
    namespace = var.namespace
  }

  data = {
    "config.json" = jsonencode({
      mcpServers = var.mcp_servers_config
    })
  }
}

resource "helm_release" "open-webui" {
  name             = "${var.project_name}-open-webui"
  repository       = var.chart_repository
  chart            = var.chart_name
  version          = var.chart_version
  create_namespace = var.create_namespace
  namespace        = var.namespace

  values = [
    yamlencode({
      fullnameOverride = "${var.project_name}-open-webui"

      ollama = {
        enabled = var.ollama_enabled
      }

      resources = {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      persistence = {
        enabled = var.enable_persistence
        size    = var.storage_size
      }

      # MCPO Configuration
      env = var.mcpo_enabled ? [
        {
          name  = "ENABLE_MCP_SERVERS"
          value = "true"
        },
        {
          name  = "MCP_CONFIG_PATH"
          value = "/app/mcpo/config.json"
        }
      ] : []

      # Volume mounts for MCPO
      extraVolumes = concat(
        var.mcpo_enabled ? [
          # ConfigMap volume for MCPO config
          {
            name = "mcpo-config"
            configMap = {
              name = kubernetes_config_map.mcpo_config[0].metadata[0].name
            }
          }
        ] : [],
        var.enable_docker_socket && var.mcpo_enabled ? [
          # Docker socket volume for container-based MCP services
          {
            name = "docker-socket"
            hostPath = {
              path = "/var/run/docker.sock"
              type = "Socket"
            }
          }
        ] : []
      )

      extraVolumeMounts = concat(
        var.mcpo_enabled ? [
          {
            name      = "mcpo-config"
            mountPath = "/app/mcpo/config.json"
            subPath   = "config.json"
            readOnly  = true
          }
        ] : [],
        var.enable_docker_socket && var.mcpo_enabled ? [
          {
            name      = "docker-socket"
            mountPath = "/var/run/docker.sock"
            readOnly  = false
          }
        ] : []
      )

      # Security context for Docker socket access
      securityContext = var.enable_docker_socket && var.mcpo_enabled ? {
        runAsUser  = 0
        runAsGroup = 0
        fsGroup    = 0
      } : {}
    })
  ]
}
