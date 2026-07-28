# PostgreSQL Helm Chart with External Storage
# Using Bitnami PostgreSQL for professional setup

# Generate secure random passwords
resource "random_password" "postgres_password" {
  length  = 20
  special = true
}

# Create PVC for PostgreSQL data on external storage
resource "kubernetes_persistent_volume" "postgresql_pv" {
  metadata {
    name = "${var.project_name}-postgresql-pv"
  }

  spec {
    capacity = {
      storage = var.storage_size
    }

    access_modes = ["ReadWriteOnce"]

    persistent_volume_source {
      host_path {
        path = "${var.external_storage_path}/postgresql"
        type = "DirectoryOrCreate"
      }
    }

    storage_class_name               = "manual"
    persistent_volume_reclaim_policy = "Retain"
  }
}

resource "kubernetes_persistent_volume_claim" "postgresql_pvc" {
  wait_until_bound = false

  metadata {
    name      = "${var.project_name}-postgresql-pvc"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = var.storage_size
      }
    }

    storage_class_name = "manual"
    volume_name        = kubernetes_persistent_volume.postgresql_pv.metadata[0].name
  }
}

# Create PostgreSQL credentials as Kubernetes secret first
resource "kubernetes_secret" "postgresql_auth" {
  metadata {
    name      = "${var.project_name}-postgresql-auth"
    namespace = var.namespace
  }

  data = {
    postgres-password = random_password.postgres_password.result
  }

  type = "Opaque"
}

# PostgreSQL Helm Chart
resource "helm_release" "postgresql" {
  name             = "${var.project_name}-postgresql"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "postgresql"
  version          = var.chart_version
  create_namespace = false
  namespace        = var.namespace

  values = [
    yamlencode({
      # Global settings
      global = {
        postgresql = {
          auth = {
            existingSecret = kubernetes_secret.postgresql_auth.metadata[0].name
            secretKeys = {
              adminPasswordKey = "postgres-password"
            }
            database = var.postgres_database
          }
        }
      }

      # Primary PostgreSQL configuration
      primary = {
        service = {
          type = "ClusterIP"
          ports = {
            postgresql = 5432
          }
        }

        persistence = {
          enabled       = true
          existingClaim = kubernetes_persistent_volume_claim.postgresql_pvc.metadata[0].name
          size          = var.storage_size
          storageClass  = "manual"
          accessModes   = ["ReadWriteOnce"]
        }

        # Enable volume permissions for external storage
        volumePermissions = {
          enabled = true
        }

        resources = {
          limits = {
            cpu    = "${var.cpu_limit}m"
            memory = "${var.memory_limit}Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }

        # PostgreSQL configuration
        postgresql = {
          configuration = {
            # Enable extensions for advanced features
            shared_preload_libraries = "pg_cron"

            # Performance tuning
            max_connections      = 100
            shared_buffers       = "128MB"
            effective_cache_size = "384MB"
            work_mem             = "4MB"
            maintenance_work_mem = "64MB"

            # WAL settings for backup
            wal_level       = "replica"
            max_wal_size    = "1GB"
            min_wal_size    = "80MB"
            archive_mode    = "on"
            archive_timeout = 60

            # Logging
            log_min_duration_statement = 1000
            log_checkpoints            = "on"
            log_connections            = "on"
            log_disconnections         = "on"

            # Timezone
            timezone = var.timezone
          }
        }

        initdb = {
          scripts = {
            "01-extensions.sql" = <<-SQL
              -- Create extensions
              CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
              CREATE EXTENSION IF NOT EXISTS "pg_cron";
              
              -- Set up pg_cron
              UPDATE pg_database SET datallowconn = TRUE WHERE datname = 'postgres';
              
              -- Grant cron permissions
              GRANT USAGE ON SCHEMA cron TO postgres;
            SQL
          }
        }
      }

      # Metrics (optional)
      metrics = {
        enabled = var.enable_metrics
        serviceMonitor = {
          enabled = false
        }
      }
    })
  ]

  depends_on = [
    kubernetes_persistent_volume_claim.postgresql_pvc,
    kubernetes_secret.postgresql_auth
  ]
}
