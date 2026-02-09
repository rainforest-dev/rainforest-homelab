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
      # Required: cluster name must be the public FQDN
      clusterName = var.public_hostname

      # Kubernetes cluster name for tsh kube access
      kubeClusterName = var.kubernetes_cluster_name

      # Multiplex all protocols on one port (required for Cloudflare Tunnel)
      proxyListenerMode = "multiplex"

      # Authentication configuration
      authentication = {
        type         = "local"
        secondFactor = "webauthn"
        webauthn = {
          rp_id = var.public_hostname
        }
      }

      # ClusterIP service since Cloudflare Tunnel handles external access
      service = {
        type = "ClusterIP"
      }

      # Persistence configuration
      persistence = {
        enabled           = true
        existingClaimName = var.use_external_storage ? kubernetes_persistent_volume_claim.teleport_pvc[0].metadata[0].name : ""
        volumeSize        = var.storage_size
      }

      # Resource limits
      resources = {
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
        limits = {
          memory = var.memory_limit
        }
      }

      # Single replica for homelab
      highAvailability = {
        replicaCount        = 1
        requireAntiAffinity = false
      }

      # Operator not needed for standalone deployment
      operator = {
        enabled = false
      }

      # Pod security policy not needed for Docker Desktop
      podSecurityPolicy = {
        enabled = false
      }

      # Auth service overrides
      auth = {
        teleportConfig = {
          auth_service = {
            session_recording = "node"
          }
        }
      }

      # Proxy service overrides
      proxy = {
        teleportConfig = {
          proxy_service = {
            web_listen_addr = "0.0.0.0:3080"
          }
        }
      }

    })
  ]

  # Wait for deployment to be ready
  wait    = true
  timeout = 600

  depends_on = [kubernetes_persistent_volume_claim.teleport_pvc]
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
      "app.kubernetes.io/name"     = "teleport-cluster"
      "app.kubernetes.io/instance" = "${var.project_name}-teleport"
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
