# Teleport OSS deployment for secure access to homelab resources
# Provides SSH, Kubernetes, Application, and Database access

# Generate random tokens for Teleport auth
resource "random_password" "teleport_auth_token" {
  length  = 32
  special = false
}

# Create persistent volume for Teleport data (session recordings, etc.)
resource "kubernetes_persistent_volume" "teleport_pv" {
  count = var.use_external_storage ? 1 : 0

  metadata {
    name = "${var.project_name}-teleport-pv"
    labels = {
      app     = "teleport"
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
        path = "${var.external_storage_path}/teleport"
        type = "DirectoryOrCreate"
      }
    }
  }
}

# Create persistent volume claim for Teleport data
resource "kubernetes_persistent_volume_claim" "teleport_pvc" {
  count = var.use_external_storage ? 1 : 0

  metadata {
    name      = "${var.project_name}-teleport-pvc"
    namespace = var.namespace
    labels = {
      app     = "teleport"
      project = var.project_name
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "manual"
    volume_name        = kubernetes_persistent_volume.teleport_pv[0].metadata[0].name

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }

  depends_on = [kubernetes_persistent_volume.teleport_pv]
}

# Deploy Teleport using Helm chart
resource "helm_release" "teleport" {
  name       = "${var.project_name}-teleport"
  repository = "https://charts.releases.teleport.dev"
  chart      = "teleport-cluster"
  version    = var.teleport_version
  namespace  = var.namespace

  values = [
    yamlencode({
      clusterName = var.cluster_name

      # Teleport authentication server configuration
      auth = {
        enabled = true
        replicas = 1
        resources = {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
        }
      }

      # Teleport proxy server configuration (handles web UI and connections)
      proxy = {
        enabled = true
        replicas = 1
        service = {
          type = "ClusterIP"
          ports = {
            https = {
              port       = 443
              targetPort = 3080
              protocol   = "TCP"
            }
            sshproxy = {
              port       = 3023
              targetPort = 3023
              protocol   = "TCP"
            }
            k8s = {
              port       = 3026
              targetPort = 3026
              protocol   = "TCP"
            }
            mysql = {
              port       = 3036
              targetPort = 3036
              protocol   = "TCP"
            }
            postgres = {
              port       = 5432
              targetPort = 5432
              protocol   = "TCP"
            }
          }
        }
        resources = {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
        }
      }

      # Persistence configuration
      persistence = {
        enabled      = var.use_external_storage
        existingClaim = var.use_external_storage ? kubernetes_persistent_volume_claim.teleport_pvc[0].metadata[0].name : null
        size         = var.use_external_storage ? null : var.storage_size
      }

      # Teleport configuration
      teleportConfig = {
        teleport = {
          log = {
            severity = "INFO"
            output   = "stderr"
          }
          data_dir = "/var/lib/teleport"
          storage = {
            type = "dir"
            path = "/var/lib/teleport/backend"
          }
        }

        auth_service = {
          enabled = true
          cluster_name = var.cluster_name

          # Authentication configuration
          authentication = {
            type          = "local"
            second_factor = "off"  # Can be "otp", "webauthn", or "on" for production
          }

          # Session recording
          session_recording = "node"  # Record sessions at the node level

          # Proxy listener
          proxy_listener_mode = "multiplex"
        }

        proxy_service = {
          enabled = true

          # Public address (will be accessed via Cloudflare Tunnel)
          public_addr = ["${var.public_hostname}:443"]

          # Kubernetes proxy
          kube_listen_addr = "0.0.0.0:3026"
          kube_public_addr = ["${var.public_hostname}:3026"]

          # Web interface
          web_listen_addr = "0.0.0.0:3080"

          # SSH proxy
          ssh_public_addr = ["${var.public_hostname}:3023"]

          # Tunnel public address (for reverse tunnels)
          tunnel_public_addr = "${var.public_hostname}:3024"

          # PostgreSQL and MySQL proxies
          postgres_public_addr = ["${var.public_hostname}:5432"]
          mysql_public_addr    = ["${var.public_hostname}:3036"]
        }

        ssh_service = {
          enabled = false  # We'll enable this when adding SSH nodes
        }
      }

      # High availability (disabled for homelab single-node setup)
      highAvailability = {
        replicaCount     = 1
        requireAntiAffinity = false
      }

      # Operator is not needed for standalone deployment
      operator = {
        enabled = false
      }

      # Service account
      serviceAccount = {
        create = true
        name   = "${var.project_name}-teleport"
      }

      # Pod security
      podSecurityPolicy = {
        enabled = false  # Not needed for Docker Desktop
      }
    })
  ]

  # Wait for deployment to be ready
  wait    = true
  timeout = 600

  depends_on = var.use_external_storage ? [kubernetes_persistent_volume_claim.teleport_pvc[0]] : []
}

# Create Kubernetes service for Teleport web UI (for Cloudflare Tunnel)
resource "kubernetes_service" "teleport_web" {
  metadata {
    name      = "${var.project_name}-teleport-web"
    namespace = var.namespace
    labels = {
      app     = "teleport"
      project = var.project_name
      service = "web"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "teleport-cluster"
      "app.kubernetes.io/component" = "proxy"
      "app.kubernetes.io/instance"  = "${var.project_name}-teleport"
    }

    port {
      name        = "https"
      port        = 3080
      target_port = 3080
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [helm_release.teleport]
}

# Create ConfigMap with Kubernetes access configuration
resource "kubernetes_config_map" "teleport_kubernetes" {
  metadata {
    name      = "${var.project_name}-teleport-kubernetes"
    namespace = var.namespace
    labels = {
      app     = "teleport"
      project = var.project_name
    }
  }

  data = {
    "kubernetes.yaml" = yamlencode({
      kind    = "kube_cluster"
      version = "v3"
      metadata = {
        name = var.kubernetes_cluster_name
      }
      spec = {
        # Kubernetes API server address (internal cluster DNS)
        kubernetes = {
          # For Docker Desktop, use the host's Kubernetes API
          kube_cluster_name = var.kubernetes_cluster_name
        }
      }
    })
  }

  depends_on = [helm_release.teleport]
}

# Create Secret with initial admin user invitation token
resource "kubernetes_secret" "teleport_admin_token" {
  metadata {
    name      = "${var.project_name}-teleport-admin-token"
    namespace = var.namespace
    labels = {
      app     = "teleport"
      project = var.project_name
    }
  }

  data = {
    token = base64encode(random_password.teleport_auth_token.result)
  }

  type = "Opaque"
}
