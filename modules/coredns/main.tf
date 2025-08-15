resource "helm_release" "coredns" {
  name       = "${var.project_name}-coredns"
  repository = "https://coredns.github.io/helm"
  chart      = "coredns"
  namespace  = var.namespace
  version    = "1.24.0"

  values = [
    yamlencode({
      # Service Configuration - LoadBalancer type for external access
      serviceType = "LoadBalancer"
      service = {
        loadBalancerIP = var.tailscale_ip
        annotations = {
          "metallb.universe.tf/address-pool" = "default"
        }
      }

      # Deployment Configuration
      deployment = {
        enabled = true
        replicas = 1
      }

      # Resource Management
      resources = {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      # Security Context
      securityContext = {
        allowPrivilegeEscalation = false
        capabilities = {
          add = ["NET_BIND_SERVICE"]
          drop = ["ALL"]
        }
        readOnlyRootFilesystem = true
        runAsNonRoot = true
        runAsUser = 1000
      }

      # Pod Security Context
      podSecurityContext = {
        fsGroup = 1000
      }

      # Node Selection
      nodeSelector = {}
      tolerations = []
      affinity = {}

      # CoreDNS Server Configuration
      servers = [
        # Primary zone for rainforest.tools domain
        {
          zones = [
            {
              zone = "rainforest.tools."
            }
          ]
          port = 53
          plugins = [
            {
              name = "errors"
            },
            {
              name = "health"
              configBlock = "lameduck 5s"
            },
            {
              name = "ready"
            },
            {
              name = "hosts"
              configBlock = join("\n", [
                "${var.tailscale_ip} homepage.rainforest.tools",
                "${var.tailscale_ip} open-webui.rainforest.tools", 
                "${var.tailscale_ip} flowise.rainforest.tools",
                "${var.tailscale_ip} n8n.rainforest.tools",
                "fallthrough"
              ])
            },
            {
              name = "prometheus"
              parameters = "0.0.0.0:9153"
            },
            {
              name = "cache"
              parameters = "30"
            },
            {
              name = "loop"
            },
            {
              name = "reload"
            },
            {
              name = "loadbalance"
            },
            {
              name = "log"
            }
          ]
        },
        # Fallback zone for all other domains
        {
          zones = [
            {
              zone = "."
            }
          ]
          port = 53
          plugins = [
            {
              name = "errors"
            },
            {
              name = "health"
              configBlock = "lameduck 5s"
            },
            {
              name = "ready"
            },
            {
              name = "forward"
              parameters = ". 8.8.8.8 8.8.4.4"
              configBlock = join("\n", [
                "max_concurrent 1000",
                "except rainforest.tools"
              ])
            },
            {
              name = "prometheus"
              parameters = "0.0.0.0:9153"
            },
            {
              name = "cache"
              parameters = "30"
            },
            {
              name = "loop"
            },
            {
              name = "reload"
            },
            {
              name = "loadbalance"
            },
            {
              name = "log"
            }
          ]
        }
      ]

      # Monitoring Configuration
      serviceMonitor = {
        enabled = false
      }

      # Prometheus metrics
      prometheus = {
        service = {
          enabled = true
          port = 9153
        }
      }
    })
  ]
}