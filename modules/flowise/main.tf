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

      # Database configuration
      env = var.database_type == "postgres" ? {
        DATABASE_TYPE = "postgres"
        DATABASE_HOST = var.database_host
        DATABASE_PORT = var.database_port
        DATABASE_NAME = var.database_name
        DATABASE_USER = var.database_user
      } : {}

      # Database password from secret
      envFrom = var.database_type == "postgres" && var.database_secret_name != "" ? [
        {
          secretRef = {
            name = var.database_secret_name
          }
        }
      ] : []

      # Additional environment variables for PostgreSQL
      extraEnvVars = var.database_type == "postgres" && var.database_secret_name != "" ? [
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
    })
  ]
}