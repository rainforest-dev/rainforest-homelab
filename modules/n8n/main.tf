resource "helm_release" "n8n" {
  name             = "${var.project_name}-n8n"
  repository       = var.chart_repository
  chart            = var.chart_name
  version          = var.chart_version
  create_namespace = var.create_namespace
  namespace        = var.namespace

  values = [
    yamlencode({
      fullnameOverride = "${var.project_name}-n8n"

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

      # Environment variables for database and storage configuration
      extraEnvs = concat(
        # Database configuration (if external database is enabled)
        var.enable_external_database ? [
          {
            name  = "DB_TYPE"
            value = "postgresdb"
          },
          {
            name  = "DB_POSTGRESDB_HOST"
            value = var.database_host
          },
          {
            name  = "DB_POSTGRESDB_PORT"
            value = var.database_port
          },
          {
            name  = "DB_POSTGRESDB_DATABASE"
            value = var.database_name
          },
          {
            name  = "DB_POSTGRESDB_USER"
            value = var.database_user
          }
        ] : [],
        
        # Database password from secret (if external database is enabled)
        var.enable_external_database && var.database_secret_name != "" ? [
          {
            name = "DB_POSTGRESDB_PASSWORD"
            valueFrom = {
              secretKeyRef = {
                name = var.database_secret_name
                key  = var.database_secret_key
              }
            }
          }
        ] : [],
        
        # S3/MinIO storage configuration (if S3 storage is enabled)
        var.enable_s3_storage ? [
          {
            name  = "N8N_DEFAULT_BINARY_DATA_MODE"
            value = "s3"
          },
          {
            name  = "N8N_BINARY_DATA_S3_ENDPOINT"
            value = var.s3_endpoint
          },
          {
            name  = "N8N_BINARY_DATA_S3_BUCKET"
            value = var.s3_bucket
          },
          {
            name  = "N8N_BINARY_DATA_S3_ACCESS_KEY"
            value = var.s3_access_key
          },
          {
            name  = "N8N_BINARY_DATA_S3_SECRET_KEY"
            value = var.s3_secret_key
          },
          {
            name  = "N8N_BINARY_DATA_S3_REGION"
            value = var.s3_region
          },
          {
            name  = "N8N_BINARY_DATA_S3_FORCE_PATH_STYLE"
            value = "true"  # Required for MinIO
          }
        ] : []
      )
    })
  ]
}
