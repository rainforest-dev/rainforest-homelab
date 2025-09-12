# Create MinIO bucket for n8n storage (when S3 storage is enabled)
resource "kubernetes_job" "create_n8n_bucket" {
  count = var.enable_s3_storage ? 1 : 0
  
  metadata {
    name      = "${var.project_name}-n8n-bucket-init"
    namespace = var.namespace
  }

  spec {
    template {
      metadata {}

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "create-bucket"
          image = "minio/mc:latest"

          command = [
            "sh",
            "-c",
            "mc alias set minio ${var.s3_endpoint} ${var.s3_access_key} ${var.s3_secret_key} && mc mb minio/${var.s3_bucket} --ignore-existing"
          ]

          env {
            name  = "MC_HOST_minio"
            value = "${var.s3_endpoint}"
          }
        }
      }
    }

    backoff_limit = 3
  }

  wait_for_completion = true

  timeouts {
    create = "5m"
    update = "5m"
  }
}