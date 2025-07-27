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

variable "enable_persistence" {
  description = "Enable persistent storage"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Storage size for PostgreSQL"
  type        = string
  default     = "10Gi"
}

variable "cpu_limit" {
  description = "CPU limit for PostgreSQL"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for PostgreSQL"
  type        = string
  default     = "512Mi"
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
}

variable "postgres_database" {
  description = "PostgreSQL database name"
  type        = string
  default     = "homelab"
}