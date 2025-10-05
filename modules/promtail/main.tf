# Promtail Helm Chart for log aggregation to Raspberry Pi Loki

resource "helm_release" "promtail" {
  name             = "${var.project_name}-promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  namespace        = var.namespace
  create_namespace = false
  version          = var.chart_version

  values = [
    yamlencode({
      # Loki endpoint (Raspberry Pi)
      config = {
        clients = [
          {
            url = var.loki_url
          }
        ]

        snippets = {
          pipelineStages = [
            {
              docker = {}
            }
          ]
        }
      }

      # Resource limits
      resources = {
        requests = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      # DaemonSet configuration
      daemonset = {
        enabled = true
      }

      # ServiceAccount
      serviceAccount = {
        create = true
        name   = "promtail"
      }

      # RBAC
      rbac = {
        create = true
      }

      # Tolerations for control-plane nodes
      tolerations = [
        {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]

      # Security context
      securityContext = {
        runAsUser  = 0
        runAsGroup = 0
        fsGroup    = 0
        capabilities = {
          drop = ["ALL"]
          add  = ["DAC_READ_SEARCH"]
        }
        readOnlyRootFilesystem = true
      }
    })
  ]
}
