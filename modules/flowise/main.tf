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

      # Database configuration and CORS setup
      extraEnvVars = concat(
        var.database_type == "postgres" ? [
          {
            name  = "DATABASE_TYPE"
            value = "postgres"
          },
          {
            name  = "DATABASE_HOST"
            value = var.database_host
          },
          {
            name  = "DATABASE_PORT"
            value = var.database_port
          },
          {
            name  = "DATABASE_NAME"
            value = var.database_name
          },
          {
            name  = "DATABASE_USER"
            value = var.database_user
          }
        ] : [],
        var.database_type == "postgres" && var.database_secret_name != "" ? [
          {
            name = "DATABASE_PASSWORD"
            valueFrom = {
              secretKeyRef = {
                name = var.database_secret_name
                key  = var.database_secret_key
              }
            }
          }
        ] : []
      )
    })
  ]
}
