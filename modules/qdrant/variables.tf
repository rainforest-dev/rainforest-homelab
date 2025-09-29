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

# Qdrant Configuration
variable "qdrant_version" {
  description = "Qdrant Docker image version"
  type        = string
  default     = "v1.11.0"  # Latest stable version
}

variable "cpu_limit" {
  description = "CPU limit in millicores"
  type        = number
  default     = 1000
}

variable "memory_limit" {
  description = "Memory limit in MB"
  type        = number
  default     = 1024  # Qdrant benefits from more memory for vector operations
}

variable "storage_size" {
  description = "Storage size for Qdrant data"
  type        = string
  default     = "20Gi"
}

variable "use_external_storage" {
  description = "Use external storage path instead of default PVC"
  type        = bool
  default     = true
}

variable "external_storage_path" {
  description = "Path to external storage for data persistence"
  type        = string
  default     = "/Volumes/Samsung T7 Touch/homelab-data"
}

# Security Configuration
variable "enable_api_key" {
  description = "Enable API key authentication for Qdrant"
  type        = bool
  default     = true
}

variable "qdrant_api_key" {
  description = "Qdrant API key (if empty, will be generated)"
  type        = string
  sensitive   = true
  default     = ""
}

# Qdrant Specific Configuration
variable "log_level" {
  description = "Log level for Qdrant (TRACE, DEBUG, INFO, WARN, ERROR)"
  type        = string
  default     = "INFO"
}

variable "disable_telemetry" {
  description = "Disable Qdrant telemetry"
  type        = bool
  default     = true
}

# Dashboard Configuration
variable "enable_dashboard" {
  description = "Enable Qdrant web dashboard (experimental feature)"
  type        = bool
  default     = true
}