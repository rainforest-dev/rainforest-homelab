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

# OAuth Configuration
variable "oauth_client_id" {
  description = "Cloudflare Access SaaS Application Client ID for OAuth Worker"
  type        = string
  default     = ""
  sensitive   = true
}

variable "oauth_client_secret" {
  description = "Cloudflare Access SaaS Application Client Secret for OAuth Worker"
  type        = string
  default     = ""
  sensitive   = true
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



variable "external_storage_path" {
  description = "Path to external storage for data persistence"
  type        = string
  default     = "/Volumes/Samsung T7 Touch/homelab-data"
}

# Open WebUI Configuration
#
#
#

# Teleport Configuration
variable "teleport_github_client_id" {
  description = "GitHub OAuth client ID for Teleport SSO (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "teleport_github_client_secret" {
  description = "GitHub OAuth client secret for Teleport SSO (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "teleport_github_organizations" {
  description = "List of GitHub organizations allowed to access Teleport"
  type        = list(string)
  default     = []
}
