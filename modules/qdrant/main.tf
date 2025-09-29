# Qdrant Vector Database
# Using official Qdrant Docker image with Kubernetes deployment

# Generate API key for Qdrant if not provided
resource "random_password" "qdrant_api_key" {
  count   = var.qdrant_api_key == "" ? 1 : 0
  length  = 32
  special = false
}

locals {
  qdrant_api_key = var.qdrant_api_key != "" ? var.qdrant_api_key : random_password.qdrant_api_key[0].result
}

# Create persistent volume for Qdrant data
resource "kubernetes_persistent_volume" "qdrant_pv" {
  count = var.use_external_storage ? 1 : 0
  
  metadata {
    name = "${var.project_name}-qdrant-pv"
  }
  
  spec {
    capacity = {
      storage = var.storage_size
    }
    
    access_modes = ["ReadWriteOnce"]
    
    persistent_volume_source {
      host_path {
        path = "${var.external_storage_path}/qdrant"
      }
    }
    
    storage_class_name = "manual"
  }
}

resource "kubernetes_persistent_volume_claim" "qdrant_pvc" {
  metadata {
    name      = "${var.project_name}-qdrant-pvc"
    namespace = var.namespace
  }
  
  spec {
    access_modes = ["ReadWriteOnce"]
    
    resources {
      requests = {
        storage = var.storage_size
      }
    }
    
    storage_class_name = var.use_external_storage ? "manual" : ""
    volume_name        = var.use_external_storage ? kubernetes_persistent_volume.qdrant_pv[0].metadata[0].name : null
  }
}

# Qdrant configuration ConfigMap
resource "kubernetes_config_map" "qdrant_config" {
  metadata {
    name      = "${var.project_name}-qdrant-config"
    namespace = var.namespace
  }

  data = {
    "config.yaml" = yamlencode({
      log_level = var.log_level
      storage = {
        storage_path = "/qdrant/storage"
      }
      service = {
        http_port = 6333
        grpc_port = 6334
      }
      cluster = {
        enabled = false  # Single node deployment for homelab
      }
      
      # Security configuration
      service = merge({
        http_port = 6333
        grpc_port = 6334
      }, var.enable_api_key ? {
        api_key = local.qdrant_api_key
      } : {})
      
      # Telemetry configuration
      telemetry_disabled = var.disable_telemetry
    })
  }
}

# Qdrant Secret for API key
resource "kubernetes_secret" "qdrant_secret" {
  count = var.enable_api_key ? 1 : 0
  
  metadata {
    name      = "${var.project_name}-qdrant-secret"
    namespace = var.namespace
  }

  data = {
    "api-key" = local.qdrant_api_key
  }
  
  type = "Opaque"
}

# Qdrant Deployment
resource "kubernetes_deployment" "qdrant" {
  metadata {
    name      = "${var.project_name}-qdrant"
    namespace = var.namespace
    
    labels = {
      app     = "qdrant"
      project = var.project_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "qdrant"
      }
    }

    template {
      metadata {
        labels = {
          app = "qdrant"
        }
      }

      spec {
        container {
          image = "qdrant/qdrant:${var.qdrant_version}"
          name  = "qdrant"

          port {
            container_port = 6333
            name          = "http"
          }
          
          port {
            container_port = 6334
            name          = "grpc"
          }

          # Resource limits
          resources {
            limits = {
              cpu    = "${var.cpu_limit}m"
              memory = "${var.memory_limit}Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          # Volume mounts
          volume_mount {
            name       = "qdrant-storage"
            mount_path = "/qdrant/storage"
          }
          
          volume_mount {
            name       = "qdrant-config"
            mount_path = "/qdrant/config"
          }

          # Environment variables
          env {
            name  = "QDRANT__SERVICE__HTTP_PORT"
            value = "6333"
          }
          
          env {
            name  = "QDRANT__SERVICE__GRPC_PORT" 
            value = "6334"
          }
          
          dynamic "env" {
            for_each = var.enable_api_key ? [1] : []
            content {
              name = "QDRANT__SERVICE__API_KEY"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret.qdrant_secret[0].metadata[0].name
                  key  = "api-key"
                }
              }
            }
          }

          # Health checks
          liveness_probe {
            http_get {
              path = "/health"
              port = 6333
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 6333
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          # Security context
          security_context {
            run_as_user                = 1000
            run_as_group              = 1000
            run_as_non_root           = true
            allow_privilege_escalation = false
          }
        }

        # Volumes
        volume {
          name = "qdrant-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.qdrant_pvc.metadata[0].name
          }
        }
        
        volume {
          name = "qdrant-config"
          config_map {
            name = kubernetes_config_map.qdrant_config.metadata[0].name
          }
        }

        # Security context for pod
        security_context {
          run_as_user  = 1000
          run_as_group = 1000
          fs_group     = 1000
        }
      }
    }
  }
}

# Qdrant Service
resource "kubernetes_service" "qdrant" {
  metadata {
    name      = "${var.project_name}-qdrant"
    namespace = var.namespace
    
    labels = {
      app     = "qdrant"
      project = var.project_name
    }
  }

  spec {
    selector = {
      app = "qdrant"
    }

    port {
      name        = "http"
      port        = 6333
      target_port = 6333
      protocol    = "TCP"
    }
    
    port {
      name        = "grpc"
      port        = 6334
      target_port = 6334
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}