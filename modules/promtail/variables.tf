variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "homelab"
}

variable "chart_version" {
  description = "Promtail Helm chart version"
  type        = string
  default     = "6.16.6"
}

variable "loki_url" {
  description = "Loki push endpoint URL (Raspberry Pi)"
  type        = string
}

variable "cpu_request" {
  description = "CPU request"
  type        = string
  default     = "50m"
}

variable "cpu_limit" {
  description = "CPU limit"
  type        = string
  default     = "100m"
}

variable "memory_request" {
  description = "Memory request"
  type        = string
  default     = "64Mi"
}

variable "memory_limit" {
  description = "Memory limit"
  type        = string
  default     = "128Mi"
}
