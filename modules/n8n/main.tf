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
  count            = var.use_external_storage ? 1 : 0
  wait_until_bound = false

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
            value = "postgresdb"
          }
          
          env {
            name  = "DB_POSTGRESDB_HOST"
            value = var.postgres_host
          }
          
          env {
            name  = "DB_POSTGRESDB_PORT"
            value = "5432"
          }
          
          env {
            name  = "DB_POSTGRESDB_DATABASE"
            value = var.database_name
          }
          
          env {
            name  = "DB_POSTGRESDB_USER"
            value = "postgres"
          }
          
          env {
            name = "DB_POSTGRESDB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "homelab-postgresql-auth"
                key  = "postgres-password"
              }
            }
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

          env {
            name  = "OBSIDIAN_API_KEY"
            value = var.obsidian_api_key
          }

          volume_mount {
            name       = "n8n-data"
            mount_path = "/home/node/.n8n"
          }

          # Drop folder for the voice-memo transcription workflow. Direct hostPath
          # (not a PV/PVC) — it is a shared inbox, not stateful data. Docker Desktop
          # n8n 2.x sandboxes the readWriteFile node to /home/node/.n8n-files, so mount
          # inside that path. Docker Desktop surfaces the Mac's T7 path into the pod (verified via marker file).
          volume_mount {
            name       = "voice-inbox"
            mount_path = "/home/node/.n8n-files/voice-inbox"
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

        volume {
          name = "voice-inbox"
          host_path {
            path = "${var.external_storage_path}/voice-inbox"
            type = "DirectoryOrCreate"
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

    # LoadBalancer (not ClusterIP) so Docker Desktop binds the service on the
    # host at localhost:5678. This lets the Docker MCP gateway reach n8n's API
    # via host.docker.internal:5678, bypassing the Cloudflare Access 302 that
    # intercepts https://n8n.rainforest.tools/api/v1/*. LoadBalancer is a
    # superset of ClusterIP, so the in-cluster DNS the tunnel uses
    # (homelab-n8n.homelab.svc.cluster.local:5678) is unchanged.
    type = "LoadBalancer"
  }
}