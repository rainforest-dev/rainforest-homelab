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
  default     = "kube-system"
}

variable "cpu_limit" {
  description = "CPU limit for metrics-server"
  type        = string
  default     = "100m"
}

variable "memory_limit" {
  description = "Memory limit for metrics-server"
  type        = string
  default     = "128Mi"
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
  default     = "3.13.0"
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = false
}
