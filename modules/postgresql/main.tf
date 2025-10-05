# PostgreSQL Helm Chart with External Storage
# Using Bitnami PostgreSQL for professional setup

# Generate secure random passwords
resource "random_password" "postgres_password" {
  length  = 20
  special = true
}

resource "random_password" "pgadmin_password" {
  length  = 16
  special = false  # Avoid special chars that might cause issues in web UI
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
    
    storage_class_name = "manual"
    persistent_volume_reclaim_policy = "Retain"
  }
}

resource "kubernetes_persistent_volume_claim" "postgresql_pvc" {
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
          enabled          = true
          existingClaim    = kubernetes_persistent_volume_claim.postgresql_pvc.metadata[0].name
          size             = var.storage_size
          storageClass     = "manual"
          accessModes      = ["ReadWriteOnce"]
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
            max_connections          = 100
            shared_buffers          = "128MB"
            effective_cache_size    = "384MB"
            work_mem               = "4MB"
            maintenance_work_mem   = "64MB"
            
            # WAL settings for backup
            wal_level               = "replica"
            max_wal_size           = "1GB"
            min_wal_size           = "80MB"
            archive_mode           = "on"
            archive_timeout        = 60
            
            # Logging
            log_min_duration_statement = 1000
            log_checkpoints        = "on"
            log_connections        = "on"
            log_disconnections     = "on"
            
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

# NodePort service to expose PostgreSQL metrics externally
resource "kubernetes_service" "postgresql_metrics" {
  count = var.enable_metrics ? 1 : 0

  metadata {
    name      = "${var.project_name}-postgresql-metrics"
    namespace = var.namespace
    labels = {
      app = "postgresql-metrics"
    }
  }

  spec {
    type = "NodePort"

    port {
      name        = "metrics"
      port        = 9187
      target_port = 9187
      node_port   = 30432
    }

    selector = {
      "app.kubernetes.io/name"     = "postgresql"
      "app.kubernetes.io/instance" = "${var.project_name}-postgresql"
    }
  }

  depends_on = [helm_release.postgresql]
}

# pgAdmin for GUI management (lean setup without external PVC)
resource "helm_release" "pgadmin" {
  count = var.enable_pgadmin ? 1 : 0
  
  name             = "${var.project_name}-pgadmin"
  repository       = "https://helm.runix.net"
  chart            = "pgadmin4"
  version          = var.pgadmin_chart_version
  create_namespace = false
  namespace        = var.namespace

  values = [
    yamlencode({
      env = {
        email    = var.pgadmin_email
        password = random_password.pgadmin_password.result
      }
      
      service = {
        type = "ClusterIP"
        port = 80
      }
      
      # Lean setup: use default storage class for pgAdmin data
      persistentVolume = {
        enabled      = true
        size         = "2Gi"
        storageClass = ""  # Use default Docker Desktop storage class
        accessModes  = ["ReadWriteOnce"]
      }
      
      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      # Pre-configure PostgreSQL server connection for immediate access
      serverDefinitions = {
        enabled = true
        servers = {
          "1" = {
            Name          = "HomeLab PostgreSQL"
            Group         = "Servers" 
            Host          = "${var.project_name}-postgresql"
            Port          = 5432
            MaintenanceDB = var.postgres_database
            Username      = "postgres"
            SSLMode       = "prefer"
          }
        }
      }
    })
  ]

  depends_on = [helm_release.postgresql]
}