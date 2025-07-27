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
  description = "CPU limit for Teleport Agent"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for Teleport Agent"
  type        = string
  default     = "512Mi"
}

variable "enable_persistence" {
  description = "Enable persistent storage"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Storage size for Teleport Agent"
  type        = string
  default     = "10Gi"
}

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://charts.releases.teleport.dev"
}

variable "chart_name" {
  description = "Helm chart name"
  type        = string
  default     = "teleport-kube-agent"
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
  default     = "17.5.2"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "teleport-agent"
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "values_file_path" {
  description = "Path to the Helm values file"
  type        = string
  default     = "prod-cluster-values.yaml"
}