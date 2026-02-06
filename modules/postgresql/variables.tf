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

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "homelab"
}

# PostgreSQL Configuration
variable "chart_version" {
  description = "PostgreSQL Helm chart version"
  type        = string
  default     = "15.2.5"  # PostgreSQL 16.2.0 - keep current stable version
}

variable "postgres_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
  default     = "postgres_secure_password_2024"
}

variable "postgres_database" {
  description = "Default PostgreSQL database"
  type        = string
  default     = "homelab"
}

variable "cpu_limit" {
  description = "CPU limit in millicores"
  type        = number
  default     = 1000
}

variable "memory_limit" {
  description = "Memory limit in MB"
  type        = number
  default     = 512
}

variable "storage_size" {
  description = "Storage size for PostgreSQL data"
  type        = string
  default     = "20Gi"
}

variable "external_storage_path" {
  description = "Path to external storage for data persistence"
  type        = string
  default     = "/Volumes/Samsung T7 Touch/homelab-data"
}

variable "timezone" {
  description = "Timezone for PostgreSQL"
  type        = string
  default     = "America/New_York"
}

# pgAdmin Configuration
variable "enable_pgadmin" {
  description = "Enable pgAdmin GUI"
  type        = bool
  default     = true
}

variable "pgadmin_chart_version" {
  description = "pgAdmin Helm chart version"
  type        = string
  default     = "1.50.0"  # Updated to latest version
}

variable "pgadmin_email" {
  description = "pgAdmin login email"
  type        = string
  default     = "contact@rainforest.tools"
}

variable "pgadmin_password" {
  description = "pgAdmin login password"
  type        = string
  sensitive   = true
  default     = "pgadmin_secure_password_2024"
}

# Monitoring
variable "enable_metrics" {
  description = "Enable PostgreSQL metrics"
  type        = bool
  default     = false
}