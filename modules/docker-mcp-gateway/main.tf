# Docker MCP Gateway Kubernetes Deployment
# Provides remote Docker MCP server accessible via Cloudflare Tunnel

resource "kubernetes_config_map" "docker_mcp_config" {
  metadata {
    name      = "${var.project_name}-docker-mcp-config"
    namespace = var.namespace
    labels = {
      app         = "docker-mcp-gateway"
      project     = var.project_name
      environment = var.environment
    }
  }

  data = {
    "config.json" = jsonencode({
      server = {
        name        = "docker-mcp-gateway"
        version     = "1.0.0"
        description = "Docker MCP Gateway for remote Docker operations"
      }
      logging = {
        level = var.log_level
      }
      docker = {
        socket_path = "/var/run/docker.sock"
        timeout     = var.docker_timeout
      }
    })
  }
}

resource "kubernetes_deployment" "docker_mcp_gateway" {
  metadata {
    name      = "${var.project_name}-docker-mcp-gateway"
    namespace = var.namespace
    labels = {
      app         = "docker-mcp-gateway"
      project     = var.project_name
      environment = var.environment
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app         = "docker-mcp-gateway"
        project     = var.project_name
        environment = var.environment
      }
    }

    template {
      metadata {
        labels = {
          app         = "docker-mcp-gateway"
          project     = var.project_name
          environment = var.environment
        }
      }

      spec {
        # Security context for the pod
        security_context {
          run_as_user  = 1000
          run_as_group = 1000
          fs_group     = 999  # Docker group ID
        }

        container {
          name  = "docker-mcp-gateway"
          image = var.docker_image

          # Install Docker and start MCP gateway
          command = ["/bin/sh"]
          args = [
            "-c",
            <<-EOT
              # Install Docker CLI in container
              if ! command -v docker &> /dev/null; then
                echo "Installing Docker CLI..."
                apk add --no-cache docker-cli
              fi
              
              # Start Docker MCP gateway
              echo "Starting Docker MCP Gateway..."
              exec docker mcp gateway run --config /config/config.json --listen 0.0.0.0:${var.port}
            EOT
          ]

          port {
            name           = "mcp-port"
            container_port = var.port
            protocol       = "TCP"
          }

          # Health checks
          liveness_probe {
            http_get {
              path = "/health"
              port = var.port
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = var.port
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          # Resource limits
          resources {
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          # Environment variables
          env {
            name  = "MCP_SERVER_NAME"
            value = "docker-mcp-gateway"
          }

          env {
            name  = "LOG_LEVEL"
            value = var.log_level
          }

          env {
            name  = "DOCKER_HOST"
            value = "unix:///var/run/docker.sock"
          }

          # Volume mounts
          volume_mount {
            name       = "docker-socket"
            mount_path = "/var/run/docker.sock"
            read_only  = false
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
            read_only  = true
          }

          # Security context for container
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
            run_as_non_root           = false  # Need root for Docker socket access
            capabilities {
              drop = ["ALL"]
              add  = ["CHOWN", "SETUID", "SETGID"]  # Minimal caps for Docker
            }
          }
        }

        # Volumes
        volume {
          name = "docker-socket"
          host_path {
            path = "/var/run/docker.sock"
            type = "Socket"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.docker_mcp_config.metadata[0].name
          }
        }

        # Node selector for Docker Desktop
        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        # Service account
        service_account_name            = kubernetes_service_account.docker_mcp_gateway.metadata[0].name
        automount_service_account_token = false
      }
    }
  }
}

# Service account for the deployment
resource "kubernetes_service_account" "docker_mcp_gateway" {
  metadata {
    name      = "${var.project_name}-docker-mcp-gateway"
    namespace = var.namespace
    labels = {
      app         = "docker-mcp-gateway"
      project     = var.project_name
      environment = var.environment
    }
  }
}

# Service to expose the Docker MCP Gateway
resource "kubernetes_service" "docker_mcp_gateway" {
  metadata {
    name      = "${var.project_name}-docker-mcp-gateway"
    namespace = var.namespace
    labels = {
      app         = "docker-mcp-gateway"
      project     = var.project_name
      environment = var.environment
    }
  }

  spec {
    selector = {
      app         = "docker-mcp-gateway"
      project     = var.project_name
      environment = var.environment
    }

    port {
      name        = "mcp-port"
      protocol    = "TCP"
      port        = var.port
      target_port = var.port
    }

    type = "ClusterIP"
  }
}

# Network policy for security (optional)
resource "kubernetes_network_policy" "docker_mcp_gateway" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "${var.project_name}-docker-mcp-gateway"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        app         = "docker-mcp-gateway"
        project     = var.project_name
        environment = var.environment
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Allow ingress from same namespace
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = var.namespace
          }
        }
      }
    }

    # Allow egress to Docker daemon and external registries
    egress {
      # Allow DNS
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
    }

    egress {
      # Allow Docker daemon communication
      to {}
      ports {
        port     = "2375"
        protocol = "TCP"
      }
      ports {
        port     = "2376"
        protocol = "TCP"
      }
    }

    egress {
      # Allow HTTPS for Docker registries
      to {}
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }
  }
}