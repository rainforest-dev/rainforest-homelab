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
  description = "CPU limit for MinIO"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for MinIO"
  type        = string
  default     = "1Gi"
}

variable "enable_persistence" {
  description = "Enable persistent storage"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Storage size for MinIO"
  type        = string
  default     = "100Gi"
}

variable "chart_repository" {
  description = "Helm chart repository for MinIO"
  type        = string
  default     = "https://charts.min.io/"
}

variable "chart_version" {
  description = "MinIO Helm chart version"
  type        = string
  default     = "5.2.0"
}

variable "minio_root_user" {
  description = "MinIO root username"
  type        = string
  default     = "admin"
}

variable "minio_root_password" {
  description = "MinIO root password (auto-generated if empty)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "replicas" {
  description = "Number of MinIO replicas"
  type        = number
  default     = 1
}

variable "mode" {
  description = "MinIO deployment mode (standalone or distributed)"
  type        = string
  default     = "standalone"
  validation {
    condition     = contains(["standalone", "distributed"], var.mode)
    error_message = "Mode must be either 'standalone' or 'distributed'."
  }
}

variable "console_enabled" {
  description = "Enable MinIO Console web interface"
  type        = bool
  default     = true
}