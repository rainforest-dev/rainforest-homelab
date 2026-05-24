# Open WebUI Configuration
variable "ollama_base_url" {
  description = "Base URL for external Ollama instance (e.g., http://host.docker.internal:11434 for local Docker Desktop)"
  type        = string
  default     = "http://host.docker.internal:11434"
}
# Environment Configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "homelab"
}

# Infrastructure Configuration
variable "docker_host" {
  description = "Docker daemon host (unix:///var/run/docker.sock for local)"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kubernetes_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = "docker-desktop"
}

variable "domain_suffix" {
  description = "Domain suffix for services"
  type        = string
  default     = "localhost"
}

# Storage Configuration
variable "docker_volume_root" {
  description = "Root path for Docker volumes"
  type        = string
  default     = "/var/lib/docker/volumes"
}

variable "enable_persistence" {
  description = "Enable persistent storage for services"
  type        = bool
  default     = true
}

# Cloudflare Configuration
variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:Read, Zone:Edit, Account:Read permissions"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_team_name" {
  description = "Cloudflare Zero Trust team name for OAuth URLs"
  type        = string
  default     = ""
}

# Feature Flags
variable "enable_teleport" {
  description = "Enable Teleport for secure access to homelab resources"
  type        = bool
  default     = false
}

variable "enable_postgresql" {
  description = "Enable PostgreSQL database service"
  type        = bool
  default     = true
}

# Resource Sizing
variable "default_cpu_limit" {
  description = "Default CPU limit for services"
  type        = string
  default     = "500m"
}

variable "default_memory_limit" {
  description = "Default memory limit for services"
  type        = string
  default     = "512Mi"
}

variable "default_storage_size" {
  description = "Default storage size for persistent volumes"
  type        = string
  default     = "10Gi"
}

variable "minio_storage_size" {
  description = "Storage size for MinIO object storage"
  type        = string
  default     = "100Gi"
}

# Zero Trust Configuration
variable "allowed_email_domains" {
  description = "List of email domains allowed to access services via Zero Trust"
  type        = list(string)
  default     = []
}

variable "allowed_emails" {
  description = "List of specific email addresses allowed to access services"
  type        = list(string)
  default     = []
}

variable "service_token_ids" {
  description = "List of Cloudflare Access Service Token IDs for programmatic access"
  type        = list(string)
  default     = []
  sensitive   = true
}

# Core feature flags
# Most services are now always-on since they're core to the homelab

variable "obsidian_api_key" {
  description = "API key for Obsidian Local REST API"
  type        = string
  sensitive   = true
  default     = ""
}

variable "external_storage_path" {
  description = "Path to external storage for data persistence"
  type        = string
  default     = "/Volumes/Samsung T7 Touch/homelab-data"
}

variable "teleport_storage_path" {
  description = "Host path for Teleport data persistence. Must be on a filesystem that supports Unix sockets (APFS/ext4). Cannot use the Samsung T7 (exFAT) because Teleport v15.5+ SQLite WAL mode requires Unix socket support."
  type        = string
  default     = "/Users/rainforest/.homelab"
}

variable "raspberry_pi_ip" {
  description = "LAN IP address of the Raspberry Pi (used to route IoT services through the Cloudflare Tunnel)"
  type        = string
  default     = "192.168.0.134"
}

variable "enable_homeassistant" {
  description = "Expose Home Assistant externally via Cloudflare Zero Trust (only enable when running on the Pi)"
  type        = bool
  default     = false
}

variable "personal_calibre_image" {
  description = "Docker image for personal-calibre (e.g. ghcr.io/rainforest-dev/rainforest-monorepo/personal-calibre:latest)"
  type        = string
  default     = "ghcr.io/rainforest-dev/rainforest-monorepo/personal-calibre:latest"
}

variable "calibre_library_path" {
  description = "Host path to the Calibre library directory (contains metadata.db and book subdirs)"
  type        = string
  default     = "/Users/rainforest/Library/CloudStorage/SynologyDrive-CalibreLibrary"
}

# Image Version Pinning
variable "open_webui_image_version" {
  description = "Open WebUI Docker image version"
  type        = string
  default     = "v0.9.5"
}

variable "cloudflared_version" {
  description = "cloudflared Docker image version"
  type        = string
  default     = "2026.5.0"
}

variable "grafana_alloy_version" {
  description = "Grafana Alloy Docker image version"
  type        = string
  default     = "v1.8.2"
}

variable "rpi_prometheus_url" {
  description = "RPi Prometheus remote_write URL for Alloy push"
  type        = string
  default     = "http://raspberrypi-5.local:30090/api/v1/write"
}

variable "rpi_loki_url" {
  description = "RPi Loki push URL for Alloy"
  type        = string
  default     = "http://raspberrypi-5.local:30100/loki/api/v1/push"
}

variable "grafana_mcp_version" {
  description = "Grafana MCP server Docker image version"
  type        = string
  default     = "0.5.0"
}

variable "grafana_mcp_api_key" {
  description = "Grafana read-only service account token for MCP server"
  type        = string
  sensitive   = true
  default     = ""
}

variable "rpi_grafana_port" {
  description = "RPi Grafana NodePort"
  type        = number
  default     = 30080
}

variable "synology_drive_path" {
  description = "Path to Synology Drive sync folder for Velero backups (empty = disabled)"
  type        = string
  default     = ""
}

