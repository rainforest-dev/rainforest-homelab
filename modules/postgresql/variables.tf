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

# PostgreSQL Configuration
variable "postgres_version" {
  description = "PostgreSQL Docker image version"
  type        = string
  default     = "16"
}

variable "postgres_user" {
  description = "PostgreSQL superuser username"
  type        = string
  default     = "postgres"
}

variable "postgres_password" {
  description = "PostgreSQL superuser password (auto-generated if empty)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgres_database" {
  description = "Default PostgreSQL database name"
  type        = string
  default     = "homelab"
}

variable "postgres_external_port" {
  description = "External port for PostgreSQL (Tailscale access)"
  type        = number
  default     = 5432
}

variable "postgres_memory_limit" {
  description = "Memory limit for PostgreSQL container"
  type        = number
  default     = 512
}

variable "postgres_cpu_limit" {
  description = "CPU limit for PostgreSQL container (fractional cores)"
  type        = number
  default     = 1.0
}

# pgAdmin Configuration
variable "pgadmin_version" {
  description = "pgAdmin Docker image version"
  type        = string
  default     = "latest"
}

variable "pgadmin_email" {
  description = "pgAdmin default admin email"
  type        = string
  default     = "contact@rainforest.tools"
}

variable "pgadmin_password" {
  description = "pgAdmin default admin password (auto-generated if empty)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "pgadmin_external_port" {
  description = "External port for pgAdmin (Tailscale access)"
  type        = number
  default     = 5050
}

variable "pgadmin_memory_limit" {
  description = "Memory limit for pgAdmin container"
  type        = number
  default     = 256
}

variable "pgadmin_cpu_limit" {
  description = "CPU limit for pgAdmin container (fractional cores)"
  type        = number
  default     = 0.5
}

# Service Database Management
# Services will self-register their databases - no centralized list needed

# External Storage
variable "external_storage_enabled" {
  description = "Enable external storage on Samsung T7 Touch"
  type        = bool
  default     = true
}

# Backup Configuration
variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = false  # Temporarily disabled while fixing pgBackRest image
}

variable "backup_schedule" {
  description = "Cron schedule for automated backups"
  type        = string
  default     = "0 2 * * *"  # Daily at 2 AM
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}