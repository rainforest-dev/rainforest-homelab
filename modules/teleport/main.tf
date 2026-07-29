# Teleport OSS deployment for secure access to homelab resources
# Provides SSH, Kubernetes, Application, and Database access

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

      # Authentication configured via auth.teleportConfig below

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

      # Remove stale debug.sock on every pod start.
      # macOS APFS via Docker Desktop virtiofs can't rebind a Unix socket left by
      # a previous process, causing crash-loops on restart.
      # Must be top-level `initContainers` — the chart silently ignores
      # `auth.extraInitContainers`. The chart auto-mounts the `data` volume
      # into every init container, so no explicit volumeMounts are needed.
      initContainers = [
        {
          name    = "remove-stale-socket"
          image   = "busybox:1.36"
          command = ["sh", "-c", "rm -f /var/lib/teleport/debug.sock"]
        }
      ]

      # Auth service overrides
      auth = {
        teleportConfig = {
          auth_service = {
            session_recording = "node"
            authentication = {
              type          = "local"
              second_factor = "on" # supports both TOTP (Google Authenticator) and WebAuthn (passkeys)
              webauthn = {
                rp_id = var.public_hostname
              }
            }
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

# Bootstrap an initial admin user if the cluster has none. Terraform can't complete the
# interactive half of Teleport's invite flow (setting a password / registering a passkey),
# but it CAN make sure an account always exists — this is what actually caused the
# "invalid username or password" outage: the cluster was deployed but this step, previously
# a manual CLAUDE.md instruction, was never run. Re-checks (and re-bootstraps if needed)
# whenever the Helm release changes, e.g. after a PVC wipe/recreate.
resource "null_resource" "bootstrap_admin_user" {
  count = var.bootstrap_admin_user ? 1 : 0

  triggers = {
    helm_release_id = helm_release.teleport.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      DEPLOY="deploy/${var.project_name}-teleport-auth"
      if kubectl exec -n ${var.namespace} "$DEPLOY" -- tctl users ls 2>/dev/null | grep -q "No users found"; then
        echo "No Teleport users found -- creating initial admin user '${var.admin_username}'"
        kubectl exec -n ${var.namespace} "$DEPLOY" -- tctl users add ${var.admin_username} --roles=${var.admin_roles} --logins=${var.admin_logins}
        echo "^ Open that signup URL in a browser once to set a password and register a passkey."
      else
        echo "Teleport already has users configured -- skipping bootstrap."
      fi
    EOT
  }

  depends_on = [helm_release.teleport, kubernetes_service.teleport_web]
}
