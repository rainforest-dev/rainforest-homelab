variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "homelab"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# n8n Container Configuration
variable "n8n_image" {
  description = "n8n Docker image"
  type        = string
  default     = "n8nio/n8n"
}

variable "n8n_version" {
  description = "n8n version tag"
  type        = string
  default     = "latest"
}

variable "n8n_port" {
  description = "External port for n8n"
  type        = number
  default     = 5678
}

variable "n8n_host" {
  description = "n8n hostname for webhooks"
  type        = string
  default     = "n8n.rainforest.tools"
}

variable "memory_limit_mb" {
  description = "Memory limit in MB for n8n container"
  type        = number
  default     = 512
}

variable "cpu_limit" {
  description = "CPU limit for n8n container"
  type        = string
  default     = "1000m"
}

# Kubernetes Configuration
variable "namespace" {
  description = "Kubernetes namespace for n8n deployment"
  type        = string
  default     = "homelab"
}

variable "use_external_storage" {
  description = "Use external storage for persistence"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Storage size for n8n data"
  type        = string
  default     = "5Gi"
}

variable "timezone" {
  description = "Timezone for n8n"
  type        = string
  default     = "America/New_York"
}

variable "encryption_key" {
  description = "n8n encryption key for securing credentials"
  type        = string
  sensitive   = true
  default     = "n8n-homelab-encryption-key-2024"
}

# External Storage
variable "external_storage_path" {
  description = "Path to external storage for data persistence"
  type        = string
  default     = "/Volumes/Samsung T7 Touch/homelab-data"
}

# Database Configuration
variable "database_name" {
  description = "PostgreSQL database name for n8n"
  type        = string
  default     = "n8n_db"
}

variable "service_user" {
  description = "PostgreSQL user for n8n service"
  type        = string
  default     = "n8n_user"
}

variable "service_password" {
  description = "PostgreSQL password for n8n service"
  type        = string
  sensitive   = true
  default     = "n8n_secure_password_2024"
}

variable "postgres_container_name" {
  description = "PostgreSQL container name"
  type        = string
  default     = "homelab-postgresql"
}

variable "postgres_user" {
  description = "PostgreSQL admin user"
  type        = string
  default     = "postgres"
}

variable "postgres_host" {
  description = "PostgreSQL host"
  type        = string
  default     = "homelab-postgresql"
}

variable "depends_on_container" {
  description = "Container dependency for database initialization"
  type        = string
  default     = "homelab-postgresql"
}