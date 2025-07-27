resource "helm_release" "homepage" {
  name             = "${var.project_name}-homepage"
  repository       = var.chart_repository
  chart            = var.chart_name
  version          = var.chart_version
  create_namespace = var.create_namespace
  namespace        = var.namespace

  values = [
    yamlencode({
      fullnameOverride = "${var.project_name}-homepage"

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

      env = [
        {
          name  = "HOMEPAGE_ALLOWED_HOSTS"
          value = "homepage.${var.domain_suffix}"
        }
      ]

      config = {
        # Bookmark section
        bookmarks = [
          {
            "Developer Tools" = [
              {
                "GitHub" = [
                  {
                    abbr = "GH"
                    href = "https://github.com/rainforest-dev"
                  }
                ]
              }
            ]
          }
        ]

        # Services section configured for your homelab
        services = [
          {
            "AI & Automation" = [
              {
                "Open WebUI" = {
                  href        = "https://open-webui.${var.domain_suffix}"
                  description = "AI Chat Interface"
                  icon        = "open-webui.png"
                }
              },
              {
                "Flowise" = {
                  href        = "https://flowise.${var.domain_suffix}"
                  description = "AI Workflow Builder"
                  icon        = "flowise.png"
                }

              },
              {
                "n8n" = {
                  href        = "https://n8n.${var.domain_suffix}"
                  description = "Workflow Automation"
                  icon        = "n8n.png"
                }

              }
            ]
          },
          {
            "Media & Files" = [
              {
                "Calibre Web" = {
                  href        = "http://${var.domain_suffix}:8083"
                  description = "Ebook Server"
                  icon        = "calibre-web.png"
                  server      = "docker-desktop"
                  container   = "homelab-calibre-web"
                }
              }
            ]
          },
          {
            "Utilities" = [
              {
                "OpenSpeedTest" = {
                  href        = "http://${var.domain_suffix}:3333"
                  description = "Network Speed Test"
                  icon        = "openspeedtest.png"
                  server      = "docker-desktop"
                  container   = "openspeedtest"
                }
              }
            ]
          }
        ]

        docker = {
          docker-desktop = {
            # Connect to Docker socket proxy on host machine
            host = "host.docker.internal"
            port = 2375
            # Use HTTP protocol
            protocol    = "http"
            api_version = "v1.41"
          }
        }

        # Widgets configuration
        widgets = [
          {
            resources = {
              cpu     = true
              memory  = true
              disk    = "/"
              network = true
            }
          },
          {
            search = {
              provider              = "google"
              showSearchSuggestions = true
              target                = "_blank"
            }
          },
          {
            kubernetes = {
              cluster = {
                show      = true
                cpu       = true
                memory    = true
                showLabel = true
                label     = "Docker Desktop Cluster"
              }
              nodes = {
                show      = true
                cpu       = true
                memory    = true
                showLabel = true
              }
            }
          }
        ]

        # Kubernetes configuration for widgets
        kubernetes = {
          mode       = "cluster"
          namespaces = ["default", "homelab", "traefik", "kube-system"]
          # Enable metrics now that metrics-server is installed
          metrics = true
        }
      }

      # Service account for Kubernetes access
      serviceAccount = {
        create = true
        name   = "${var.project_name}-homepage"
      }

      # Enable RBAC for Kubernetes access
      enableRbac = true
    })
  ]
}
