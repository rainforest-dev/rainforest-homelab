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
  description = "CPU limit for Wetty"
  type        = string
  default     = "200m"
}

variable "memory_limit" {
  description = "Memory limit for Wetty"
  type        = string
  default     = "256Mi"
}

variable "enable_persistence" {
  description = "Enable persistent storage"
  type        = bool
  default     = false
}

variable "storage_size" {
  description = "Storage size for Wetty"
  type        = string
  default     = "1Gi"
}

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://charts.cowboysysop.github.io/"
}

variable "chart_name" {
  description = "Helm chart name"
  type        = string
  default     = "wetty"
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

variable "wetty_user" {
  description = "Username for Wetty terminal access"
  type        = string
  default     = "wetty"
}

variable "wetty_port" {
  description = "Port for Wetty service"
  type        = number
  default     = 3000
}