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
                  description = "AI Chat Interface with Claude & OpenAI"
                  icon        = "open-webui.png"
                }
              },
              {
                "Flowise" = {
                  href        = "https://flowise.${var.domain_suffix}"
                  description = "Low-code AI Workflow Builder"
                  icon        = "flowise.png"
                }
              },
              {
                "n8n" = {
                  href        = "https://n8n.${var.domain_suffix}"
                  description = "Workflow Automation Platform"
                  icon        = "n8n.png"
                }
              },
              {
                "Whisper STT" = {
                  href        = "https://whisper.${var.domain_suffix}"
                  description = "Speech-to-Text API Service"
                  icon        = "whisper.png"
                }
              }
            ]
          },
          {
            "Storage & Files" = [
              {
                "Calibre Web" = {
                  href        = "https://calibre-web.${var.domain_suffix}"
                  description = "Ebook Library & Reader"
                  icon        = "calibre-web.png"
                  server      = "docker-desktop"
                  container   = "homelab-calibre-web"
                }
              },
              {
                "MinIO Console" = {
                  href        = "https://minio.${var.domain_suffix}"
                  description = "S3-Compatible Object Storage"
                  icon        = "minio.png"
                }
              },
              {
                "MinIO S3 API" = {
                  href        = "https://s3.${var.domain_suffix}"
                  description = "S3 API Endpoint"
                  icon        = "minio.png"
                }
              }
            ]
          },
          {
            "Database & Admin" = [
              {
                "pgAdmin" = {
                  href        = "https://pgadmin.${var.domain_suffix}"
                  description = "PostgreSQL Database Admin"
                  icon        = "pgadmin.png"
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
          namespaces = ["default", "homelab", "kube-system"]
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
