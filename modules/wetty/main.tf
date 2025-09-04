# Wetty deployment - web terminal accessible via Tailscale only
resource "kubernetes_deployment" "wetty" {
  metadata {
    name      = "wetty"
    namespace = "homelab"
    labels = {
      app = "wetty"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wetty"
      }
    }

    template {
      metadata {
        labels = {
          app = "wetty"
        }
      }

      spec {
        container {
          image = "wettyoss/wetty:latest"
          name  = "wetty"

          port {
            container_port = 3000
            name          = "http"
          }

          # Environment variables for basic configuration
          env {
            name  = "PORT"
            value = "3000"
          }

          # Basic resource limits
          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          # Health checks
          liveness_probe {
            http_get {
              path = "/"
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        # Security context
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }
      }
    }
  }
}

# NodePort service for Tailscale access - NOT exposed via Traefik
resource "kubernetes_service" "wetty" {
  metadata {
    name      = "wetty"
    namespace = "homelab"
    labels = {
      app = "wetty"
    }
    annotations = {
      "tailscale.com/expose" = "true"
    }
  }

  spec {
    type = "NodePort"
    
    selector = {
      app = "wetty"
    }

    port {
      name        = "http"
      port        = 3000
      target_port = 3000
      node_port   = 30080  # Fixed NodePort for consistent Tailscale access
    }
  }
}