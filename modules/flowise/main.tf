resource "helm_release" "flowise" {
  name             = "${var.project_name}-flowise"
  repository       = var.chart_repository
  chart            = var.chart_name
  version          = var.chart_version
  create_namespace = var.create_namespace
  namespace        = var.namespace

  values = [
    yamlencode({
      fullnameOverride = "${var.project_name}-flowise"

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