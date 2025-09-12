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
  description = "CPU limit for n8n"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for n8n"
  type        = string
  default     = "512Mi"
}

variable "enable_persistence" {
  description = "Enable persistent storage"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Storage size for n8n"
  type        = string
  default     = "10Gi"
}

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "oci://8gears.container-registry.com/library/"
}

variable "chart_name" {
  description = "Helm chart name"
  type        = string
  default     = "n8n"
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

# Database Configuration
variable "enable_external_database" {
  description = "Enable external PostgreSQL database instead of SQLite"
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
  default     = "n8n"
}

variable "database_user" {
  description = "PostgreSQL database user"
  type        = string
  default     = "n8n"
}

variable "database_password" {
  description = "PostgreSQL database password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "database_secret_name" {
  description = "Kubernetes secret name containing database password"
  type        = string
  default     = ""
}

variable "database_secret_key" {
  description = "Key within the secret containing database password"
  type        = string
  default     = "postgres-password"
}

# S3/MinIO Configuration
variable "enable_s3_storage" {
  description = "Enable S3-compatible storage for file nodes"
  type        = bool
  default     = false
}

variable "s3_endpoint" {
  description = "S3 endpoint URL"
  type        = string
  default     = ""
}

variable "s3_bucket" {
  description = "S3 bucket name for n8n files"
  type        = string
  default     = "n8n-storage"
}

variable "s3_access_key" {
  description = "S3 access key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "s3_secret_key" {
  description = "S3 secret key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "s3_region" {
  description = "S3 region"
  type        = string
  default     = "us-east-1"
}