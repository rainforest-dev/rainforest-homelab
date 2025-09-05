provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "orbstack"
  }
}

# ConfigMap for MCP Gateway configuration
resource "kubernetes_config_map" "mcp_gateway_config" {
  metadata {
    name      = "mcp-gateway-config"
    namespace = var.namespace
  }

  data = {
    "registry.yaml" = yamlencode({
      servers = {
        for name, server in var.mcp_servers : name => {
          image       = server.image
          description = server.description
          environment = merge(
            server.environment,
            name == "docker" ? { DOCKER_HOST = var.docker_host } : {}
          )
        }
      }
    })
    
    "tools.yaml" = yamlencode({
      tools = var.enabled_tools
    })
  }
}

# Secret for MCP Gateway (if needed for authentication)
resource "kubernetes_secret" "mcp_gateway_secret" {
  metadata {
    name      = "mcp-gateway-secret"
    namespace = var.namespace
  }

  data = {
    api_key = base64encode("changeme-secure-key")
  }

  type = "Opaque"
}

# MCP Gateway Deployment
resource "kubernetes_deployment" "mcp_gateway" {
  metadata {
    name      = "mcp-gateway"
    namespace = var.namespace
    labels = {
      app = "mcp-gateway"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mcp-gateway"
      }
    }

    template {
      metadata {
        labels = {
          app = "mcp-gateway"
        }
      }

      spec {
        container {
          image = "docker/mcp-gateway:${var.image_tag}"
          name  = "mcp-gateway"
          
          # Note: Entrypoint is already set to /docker-mcp gateway run
          args = concat([
            "--port", tostring(var.gateway_port),
            "--transport", var.transport_mode,
            "--registry", "/config/registry.yaml", 
            "--tools-config", "/config/tools.yaml",
            "--verbose",
            "--long-lived",
            "--log-calls"
          ], 
          var.security_block_network ? ["--block-network"] : [],
          var.security_block_secrets ? ["--block-secrets"] : []
          )

          port {
            container_port = var.gateway_port
            name          = "http"
            protocol      = "TCP"
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
            read_only  = true
          }

          env {
            name  = "DOCKER_HOST"
            value = var.docker_host
          }

          env {
            name  = "MCP_GATEWAY_PORT"
            value = tostring(var.gateway_port)
          }

          env {
            name = "MCP_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mcp_gateway_secret.metadata[0].name
                key  = "api_key"
              }
            }
          }

          resources {
            limits = {
              cpu    = var.resource_limits.cpu
              memory = var.resource_limits.memory
            }
            requests = {
              cpu    = var.resource_requests.cpu
              memory = var.resource_requests.memory
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = var.gateway_port
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = var.gateway_port
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 3
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.mcp_gateway_config.metadata[0].name
          }
        }

        restart_policy = "Always"
      }
    }
  }
}

# Service for MCP Gateway
resource "kubernetes_service" "mcp_gateway" {
  metadata {
    name      = "mcp-gateway"
    namespace = var.namespace
    labels = {
      app = "mcp-gateway"
    }
  }

  spec {
    selector = {
      app = "mcp-gateway"
    }

    port {
      name        = "http"
      port        = 80
      target_port = var.gateway_port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}