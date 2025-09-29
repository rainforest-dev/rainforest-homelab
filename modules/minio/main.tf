# Generate random password for MinIO if not provided
resource "random_password" "minio_root_password" {
  count   = var.minio_root_password == "" ? 1 : 0
  length  = 20
  special = true
}

locals {
  minio_password = var.minio_root_password != "" ? var.minio_root_password : random_password.minio_root_password[0].result
}

resource "helm_release" "minio" {
  name             = "${var.project_name}-minio"
  repository       = var.chart_repository
  chart            = "minio"
  namespace        = var.namespace
  create_namespace = true
  version          = var.chart_version

  values = [
    yamlencode({
      fullnameOverride = "${var.project_name}-minio"

      # MinIO mode (standalone or distributed)
      mode = var.mode

      # Number of replicas
      replicas = var.replicas

      # MinIO root credentials
      rootUser     = var.minio_root_user
      rootPassword = local.minio_password

      # Resource limits
      resources = {
        requests = {
          cpu    = "250m"
          memory = "512Mi"
        }
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      # Persistence configuration  
      persistence = var.use_external_storage ? {
        enabled        = false  # Disable helm persistence when using external storage
        existingClaim  = ""     # No existing claim
        storageClass   = ""     # No storage class
      } : {
        enabled = var.enable_persistence
        size    = var.storage_size
      }

      # External storage configuration
      extraVolumes = var.use_external_storage ? [
        {
          name = "external-storage"
          hostPath = {
            path = "/Volumes/Samsung T7 Touch/homelab-data/minio"
            type = "DirectoryOrCreate"
          }
        }
      ] : []

      extraVolumeMounts = var.use_external_storage ? [
        {
          name      = "external-storage"
          mountPath = "/data"
        }
      ] : []

      # Service configuration for MinIO S3 API
      service = {
        type = "ClusterIP"
        port = 9000
      }

      # Console service configuration
      consoleService = {
        enabled = var.console_enabled
        type    = "ClusterIP"
        port    = 9001
      }

      # Security context
      securityContext = {
        enabled                  = true
        runAsUser                = 1000
        runAsGroup               = 1000
        fsGroup                  = 1000
        runAsNonRoot             = true
        allowPrivilegeEscalation = false
      }

      # Environment variables
      environment = {
        MINIO_PROMETHEUS_AUTH_TYPE = "public"
      }

      # Default buckets to create
      defaultBuckets = "default"

      # Network policy
      networkPolicy = {
        enabled = false
      }

      # Pod annotations
      podAnnotations = {}

      # Pod labels
      podLabels = {}
    })
  ]

  depends_on = []
}