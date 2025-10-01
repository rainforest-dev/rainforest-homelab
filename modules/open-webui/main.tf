terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

locals {
  # Environment variables for Open WebUI
  common_env_vars = concat(
    [
      "WEBUI_NAME=Open WebUI",
      "ENABLE_SIGNUP=true",
      "ENABLE_LOGIN_FORM=true",
      "ENABLE_WEBSOCKET=true"
    ],
    var.ollama_base_url != "" ? ["OLLAMA_BASE_URL=${var.ollama_base_url}"] : [],
    var.database_url != "" ? ["DATABASE_URL=${var.database_url}"] : [],
    var.whisper_stt_url != "" ? [
      "AUDIO_STT_ENGINE=openai",
      "AUDIO_STT_OPENAI_API_BASE_URL=${var.whisper_stt_url}/v1"
    ] : []
  )
}

# Docker deployment for Open WebUI with PostgreSQL
resource "docker_network" "open_webui_network" {
  count = var.deployment_type == "docker" ? 1 : 0
  name  = "${var.project_name}-open-webui-network"
  
  labels {
    label = "project"
    value = var.project_name
  }
}

# Volume management for Open WebUI data
module "open_webui_data_volume" {
  count = var.deployment_type == "docker" && var.enable_persistence ? 1 : 0
  
  source = "../volume-management"
  
  project_name         = var.project_name
  service_name         = "open-webui"
  volume_name          = "data"
  environment          = var.environment
  volume_type          = "data"
  use_external_storage = true
}

# Open WebUI Docker container
resource "docker_container" "open_webui" {
  count = var.deployment_type == "docker" ? 1 : 0
  
  image   = "ghcr.io/open-webui/open-webui:main"
  name    = "${var.project_name}-open-webui"
  restart = "unless-stopped"

  # Network configuration
  networks_advanced {
    name = docker_network.open_webui_network[0].name
  }

  # Connect to PostgreSQL network if database is configured
  dynamic "networks_advanced" {
    for_each = var.database_url != "" ? [1] : []
    content {
      name = "${var.project_name}-postgres-network"
    }
  }

  # Port mapping for Tailscale access
  ports {
    internal = 8080
    external = 8080
  }

  # Environment variables
  env = local.common_env_vars

  # Volume mounts for persistence
  dynamic "volumes" {
    for_each = var.enable_persistence ? [1] : []
    content {
      container_path = "/app/backend/data"
      volume_name    = module.open_webui_data_volume[0].volume_name
    }
  }

  # Health check
  healthcheck {
    test         = ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "60s"
  }

  # Resource limits (convert from Kubernetes format)
  memory = tonumber(replace(replace(var.memory_limit, "Gi", ""), "Mi", "")) * (
    strcontains(var.memory_limit, "Gi") ? 1024 : 1
  )

  # Labels
  labels {
    label = "project"
    value = var.project_name
  }

  labels {
    label = "service"
    value = "open-webui"
  }

  labels {
    label = "environment"
    value = var.environment
  }
}

# Helm deployment (legacy/fallback)
resource "helm_release" "open-webui" {
  count = var.deployment_type == "helm" ? 1 : 0
  
  name             = "${var.project_name}-open-webui"
  repository       = var.chart_repository
  chart            = var.chart_name
  version          = var.chart_version
  create_namespace = var.create_namespace
  namespace        = var.namespace

  values = [
    yamlencode({
      fullnameOverride = "${var.project_name}-open-webui"

      ollama = {
        enabled = var.ollama_enabled
      }

      # Configure external Ollama URLs for automatic connection
      ollamaUrls = var.ollama_base_url != "" ? [var.ollama_base_url] : []

      # Environment variables for Open WebUI configuration
      extraEnvVars = concat(
        var.ollama_base_url != "" ? [
          {
            name  = "OLLAMA_BASE_URL"
            value = var.ollama_base_url
          }
        ] : [],
        var.database_url != "" ? [
          {
            name  = "DATABASE_URL"
            value = var.database_url
          }
        ] : [],
        var.whisper_stt_url != "" ? [
          {
            name  = "AUDIO_STT_ENGINE"
            value = "openai"
          },
          {
            name  = "AUDIO_STT_OPENAI_API_BASE_URL"
            value = "${var.whisper_stt_url}/v1"
          }
        ] : []
      )

      # WebSocket support
      websocket = {
        enabled = true
      }

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

      persistence = {
        enabled = var.enable_persistence
        size    = var.storage_size
      }
    })
  ]
}
