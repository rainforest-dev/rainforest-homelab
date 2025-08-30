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

      # Configure external Ollama URLs for automatic connection
      ollamaUrls = var.ollama_base_url != "" ? [var.ollama_base_url] : []

      # Environment variables for Open WebUI configuration
      extraEnvVars = var.ollama_base_url != "" ? [
        {
          name  = "OLLAMA_BASE_URL"
          value = var.ollama_base_url
        }
      ] : []

      # WebSocket support (optional, can be removed if not needed)
      websocket = {
        enabled = var.ollama_base_url != "" ? true : false
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
    })
  ]
}
