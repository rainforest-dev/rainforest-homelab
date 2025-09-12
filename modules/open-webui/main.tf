# Data sources for retrieving secrets when external services are enabled
data "kubernetes_secret" "postgresql_password" {
  count = var.enable_external_database ? 1 : 0
  metadata {
    name      = "${var.project_name}-postgresql"
    namespace = var.namespace
  }
}

data "kubernetes_secret" "minio_credentials" {
  count = var.enable_s3_storage ? 1 : 0
  metadata {
    name      = "${var.project_name}-minio"
    namespace = var.namespace
  }
}

locals {
  # Get PostgreSQL password from secret if external database is enabled
  postgres_password = var.enable_external_database && length(data.kubernetes_secret.postgresql_password) > 0 ? data.kubernetes_secret.postgresql_password[0].data["postgres-password"] : var.database_password

  # Get MinIO credentials from secret if S3 storage is enabled  
  minio_secret_key = var.enable_s3_storage && length(data.kubernetes_secret.minio_credentials) > 0 ? data.kubernetes_secret.minio_credentials[0].data["root-password"] : var.s3_secret_key
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

      # Configure external Ollama URLs for automatic connection
      ollamaUrls = var.ollama_base_url != "" ? [var.ollama_base_url] : []

      # Database configuration - PostgreSQL connection string
      databaseUrl = var.enable_external_database && var.database_host != "" ? "postgresql://${var.database_user}:${local.postgres_password}@${var.database_host}:${var.database_port}/${var.database_name}" : ""

      # Environment variables for Open WebUI configuration
      extraEnvVars = concat(
        # Ollama configuration
        var.ollama_base_url != "" ? [
          {
            name  = "OLLAMA_BASE_URL"
            value = var.ollama_base_url
          }
        ] : [],
        
        # S3/MinIO storage configuration (experimental - may need adjustment based on Open WebUI version)
        var.enable_s3_storage && var.s3_endpoint != "" ? [
          {
            name  = "AWS_ACCESS_KEY_ID"
            value = var.s3_access_key
          },
          {
            name  = "AWS_SECRET_ACCESS_KEY"
            value = local.minio_secret_key
          },
          {
            name  = "AWS_S3_ENDPOINT_URL"
            value = var.s3_endpoint
          },
          {
            name  = "AWS_DEFAULT_REGION"
            value = var.s3_region
          },
          {
            name  = "AWS_S3_BUCKET"
            value = var.s3_bucket
          }
        ] : []
      )

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
        enabled = var.enable_persistence && !var.enable_external_database
        size    = var.storage_size
      }
    })
  ]
}
