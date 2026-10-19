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
    access_modes       = ["ReadWriteOnce"]
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
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "manual"
    volume_name        = kubernetes_persistent_volume.n8n_pv[0].metadata[0].name

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

    # Stop the old pod before starting the new one. A rolling update would run two n8n
    # versions against the same database while the new one runs its migrations.
    strategy {
      type = "Recreate"
    }

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
            name           = "http"
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
            name  = "EXECUTIONS_DATA_PRUNE"
            value = "true"
          }

          env {
            name  = "EXECUTIONS_DATA_MAX_AGE"
            value = tostring(var.executions_max_age_hours)
          }

          env {
            name  = "EXECUTIONS_DATA_PRUNE_MAX_COUNT"
            value = "5000"
          }

          env {
            name  = "GENERIC_TIMEZONE"
            value = var.timezone
          }

          dynamic "env" {
            for_each = {
              N8N_METRICS                                     = "true"
              N8N_METRICS_INCLUDE_WORKFLOW_ID_LABEL           = "true"
              N8N_METRICS_INCLUDE_WORKFLOW_NAME_LABEL         = "true"
              N8N_METRICS_INCLUDE_MESSAGE_EVENT_BUS_METRICS   = "true"
              N8N_METRICS_INCLUDE_WORKFLOW_EXECUTION_DURATION = "true"
              N8N_METRICS_INCLUDE_WORKFLOW_STATISTICS         = "true"
              N8N_OTEL_ENABLED                                = "true"
              N8N_OTEL_EXPORTER_OTLP_ENDPOINT                 = "http://host.docker.internal:4318"
              N8N_OTEL_EXPORTER_OTLP_PROTOCOL                 = "http/protobuf"
              N8N_OTEL_EXPORTER_SERVICE_NAME                  = "n8n"
              N8N_OTEL_TRACES_INCLUDE_NODE_SPANS              = "true"
              N8N_OTEL_TRACES_SAMPLE_RATE                     = "1"
            }
            content {
              name  = env.key
              value = env.value
            }
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

          # Shared inbox: only the iCloud Inbox/ folder, nothing else from the home
          # directory. The inbox workflow polls it; see configs/n8n/README.md.
          volume_mount {
            name       = "inbox"
            mount_path = "/home/node/.n8n-files/inbox"
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

        volume {
          name = "inbox"
          host_path {
            path = var.inbox_host_path
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
# n8n 2.43 leaves an unsaved execution's binary files on disk, where the execution prune never finds them.
resource "kubernetes_cron_job_v1" "binary_data_cleanup" {
  count = var.use_external_storage ? 1 : 0

  metadata {
    name      = "${var.project_name}-n8n-binary-cleanup"
    namespace = var.namespace
    labels    = { app = "n8n-binary-cleanup" }
  }

  spec {
    schedule                      = "17 * * * *"
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 3

    job_template {
      metadata { labels = { app = "n8n-binary-cleanup" } }
      spec {
        backoff_limit = 1
        template {
          metadata { labels = { app = "n8n-binary-cleanup" } }
          spec {
            restart_policy = "Never"

            container {
              name    = "cleanup"
              image   = "busybox:1.36"
              command = ["/bin/sh", "-c"]
              args = [
                "set -eu; before=$(du -sk /binary | cut -f1); find /binary/workflows -mindepth 3 -maxdepth 3 -type d -path '*/executions/*' -mmin +${var.binary_data_max_age_minutes} -exec rm -rf {} +; echo \"binaryData $before KiB -> $(du -sk /binary | cut -f1) KiB\""
              ]

              resources {
                limits   = { cpu = "200m", memory = "64Mi" }
                requests = { cpu = "10m", memory = "16Mi" }
              }

              volume_mount {
                name       = "binary"
                mount_path = "/binary"
              }
            }

            volume {
              name = "binary"
              host_path {
                path = "${var.external_storage_path}/n8n/binaryData"
                type = "DirectoryOrCreate"
              }
            }
          }
        }
      }
    }
  }
}
