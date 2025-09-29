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

variable "cpu_limit" {
  description = "CPU limit for Flowise"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for Flowise"
  type        = string
  default     = "512Mi"
}

variable "enable_persistence" {
  description = "Enable persistent storage"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Storage size for Flowise"
  type        = string
  default     = "10Gi"
}

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://cowboysysop.github.io/charts"
}

variable "chart_name" {
  description = "Helm chart name"
  type        = string
  default     = "flowise"
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
  default     = null
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = true
}

# Database configuration
variable "database_type" {
  description = "Database type: sqlite or postgres"
  type        = string
  default     = "sqlite"
}

variable "database_host" {
  description = "PostgreSQL database host"
  type        = string
  default     = ""
}

variable "database_port" {
  description = "PostgreSQL database port"
  type        = string
  default     = "5432"
}

variable "database_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = ""
}

variable "database_user" {
  description = "PostgreSQL database user"
  type        = string
  default     = ""
}

variable "database_secret_name" {
  description = "Kubernetes secret name containing database password"
  type        = string
  default     = ""
}

variable "database_secret_key" {
  description = "Key in the secret containing database password"
  type        = string
  default     = "postgres-password"
}