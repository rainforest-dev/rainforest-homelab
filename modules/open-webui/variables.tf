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
  description = "CPU limit for Open WebUI"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for Open WebUI"
  type        = string
  default     = "512Mi"
}

variable "enable_persistence" {
  description = "Enable persistent storage"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Storage size for Open WebUI"
  type        = string
  default     = "10Gi"
}

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://helm.openwebui.com/"
}

variable "chart_name" {
  description = "Helm chart name"
  type        = string
  default     = "open-webui"
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

variable "ollama_enabled" {
  description = "Enable Ollama integration"
  type        = bool
  default     = false
}

variable "ollama_base_url" {
  description = "Ollama base URL for external Ollama instance"
  type        = string
  default     = ""
}

# Database configuration variables
variable "enable_external_database" {
  description = "Enable external PostgreSQL database instead of default SQLite"
  type        = bool
  default     = false
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
  default     = "openwebui"
}

variable "database_user" {
  description = "PostgreSQL database user"
  type        = string
  default     = "openwebui"
}

variable "database_password" {
  description = "PostgreSQL database password"
  type        = string
  default     = ""
  sensitive   = true
}

# MinIO S3 storage configuration variables
variable "enable_s3_storage" {
  description = "Enable S3/MinIO storage for file uploads and exports"
  type        = bool
  default     = false
}

variable "s3_endpoint" {
  description = "S3/MinIO endpoint URL"
  type        = string
  default     = ""
}

variable "s3_access_key" {
  description = "S3/MinIO access key"
  type        = string
  default     = ""
}

variable "s3_secret_key" {
  description = "S3/MinIO secret key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "s3_bucket" {
  description = "S3/MinIO bucket name for Open WebUI storage"
  type        = string
  default     = "openwebui"
}

variable "s3_region" {
  description = "S3/MinIO region"
  type        = string
  default     = "us-east-1"
}

