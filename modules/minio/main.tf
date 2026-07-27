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
        enabled       = false # Disable helm persistence when using external storage
        existingClaim = ""    # No existing claim
        storageClass  = ""    # No storage class
        } : {
        enabled = var.enable_persistence
        size    = var.storage_size
      }

      # External storage configuration
      extraVolumes = concat(
        var.use_external_storage ? [
          {
            name = "external-storage"
            hostPath = {
              path = "/Volumes/Samsung T7 Touch/homelab-data/minio"
              type = "DirectoryOrCreate"
            }
          }
        ] : [],
        var.synology_drive_path != "" ? [
          {
            name = "synology-velero"
            hostPath = {
              path = var.synology_drive_path
              type = "DirectoryOrCreate"
            }
          }
        ] : []
      )

      extraVolumeMounts = concat(
        var.use_external_storage ? [
          {
            name      = "external-storage"
            mountPath = "/data"
          }
        ] : [],
        var.synology_drive_path != "" ? [
          {
            name      = "synology-velero"
            mountPath = "/data/velero"
          }
        ] : []
      )

      # Service configuration for MinIO S3 API
      service = {
        # LoadBalancer so Docker Desktop binds port 9000 on all host interfaces,
        # making MinIO reachable at 192.168.0.126:9000 from the Pi network.
        type = "LoadBalancer"
        port = 9000
      }

      # Console service configuration
      consoleService = {
        enabled = var.console_enabled
        type    = "LoadBalancer"
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

# Guarantee the backup-pipeline buckets exist. MinIO's chart `defaultBuckets` only
# provisions on FIRST install, so the 2026-07 MinIO reinstall silently dropped
# `velero` and `pi5-docker-backup` — every nightly Velero and docker-volume-backup
# upload failed with NoSuchBucket for days before it was caught. This idempotently
# (re)creates them via `mc mb -p` after MinIO is up, and re-runs whenever the MinIO
# release changes (so a future reinstall self-heals). Creds are read from the k8s
# secret at run time so no secret lands in the Terraform config or state.
resource "null_resource" "minio_buckets" {
  triggers = {
    buckets  = join(",", var.provisioned_buckets)
    revision = helm_release.minio.metadata[0].revision
  }

  provisioner "local-exec" {
    command = <<-BASH
      set -e
      RU=$(kubectl get secret ${var.project_name}-minio -n ${var.namespace} -o jsonpath='{.data.rootUser}' | base64 -d)
      RP=$(kubectl get secret ${var.project_name}-minio -n ${var.namespace} -o jsonpath='{.data.rootPassword}' | base64 -d)
      for b in ${join(" ", var.provisioned_buckets)}; do
        docker run --rm -e RU="$RU" -e RP="$RP" --entrypoint sh minio/mc -c \
          'mc alias set m http://host.docker.internal:9000 "$RU" "$RP" >/dev/null 2>&1 && mc mb -p m/'"$b"' 2>&1 | tail -1'
      done
    BASH
  }

  depends_on = [helm_release.minio]
}