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
    })
  ]
}
