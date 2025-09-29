# n8n Kubernetes Helm Chart deployment

# Create persistent volume for n8n data
resource "kubernetes_persistent_volume" "n8n_pv" {
  count = var.use_external_storage ? 1 : 0

  metadata {
    name = "${var.project_name}-n8n-pv"
    labels = {
      app     = "n8n"
      project = var.project_name
    }
  }

  spec {
    capacity = {
      storage = var.storage_size
    }
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "manual"
    
    persistent_volume_source {
      host_path {
        path = "${var.external_storage_path}/n8n"
        type = "DirectoryOrCreate"
      }
    }
  }
}

# Create persistent volume claim for n8n data
resource "kubernetes_persistent_volume_claim" "n8n_pvc" {
  count = var.use_external_storage ? 1 : 0

  metadata {
    name      = "${var.project_name}-n8n-pvc"
    namespace = var.namespace
    labels = {
      app     = "n8n"
      project = var.project_name
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "manual"
    volume_name = kubernetes_persistent_volume.n8n_pv[0].metadata[0].name
    
    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }

  depends_on = [kubernetes_persistent_volume.n8n_pv]
}

# Deploy n8n using Kubernetes manifests
resource "kubernetes_deployment" "n8n" {
  metadata {
    name      = "${var.project_name}-n8n"
    namespace = var.namespace
    labels = {
      app     = "n8n"
      project = var.project_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app     = "n8n"
        project = var.project_name
      }
    }

    template {
      metadata {
        labels = {
          app     = "n8n"
          project = var.project_name
        }
      }

      spec {
        container {
          name  = "n8n"
          image = "${var.n8n_image}:${var.n8n_version}"

          port {
            container_port = 5678
            name          = "http"
          }

          env {
            name  = "NODE_ENV"
            value = "production"
          }
          
          env {
            name  = "DB_TYPE"
            value = "sqlite"
          }
          
          env {
            name  = "N8N_ENCRYPTION_KEY"
            value = var.encryption_key
          }
          
          env {
            name  = "N8N_HOST"
            value = var.n8n_host
          }
          
          env {
            name  = "N8N_PORT"
            value = "5678"
          }
          
          env {
            name  = "N8N_PROTOCOL"
            value = "https"
          }
          
          env {
            name  = "WEBHOOK_URL"
            value = "https://${var.n8n_host}"
          }
          
          env {
            name  = "GENERIC_TIMEZONE"
            value = var.timezone
          }

          volume_mount {
            name       = "n8n-data"
            mount_path = "/home/node/.n8n"
          }

          resources {
            limits = {
              cpu    = var.cpu_limit
              memory = "${var.memory_limit_mb}Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 5678
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 5678
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }

        volume {
          name = "n8n-data"
          
          dynamic "persistent_volume_claim" {
            for_each = var.use_external_storage ? [1] : []
            content {
              claim_name = kubernetes_persistent_volume_claim.n8n_pvc[0].metadata[0].name
            }
          }
          
          dynamic "empty_dir" {
            for_each = var.use_external_storage ? [] : [1]
            content {
              size_limit = var.storage_size
            }
          }
        }
      }
    }
  }
}

# Create service for n8n
resource "kubernetes_service" "n8n" {
  metadata {
    name      = "${var.project_name}-n8n"
    namespace = var.namespace
    labels = {
      app     = "n8n"
      project = var.project_name
    }
  }

  spec {
    selector = {
      app     = "n8n"
      project = var.project_name
    }

    port {
      name        = "http"
      port        = 5678
      target_port = 5678
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}