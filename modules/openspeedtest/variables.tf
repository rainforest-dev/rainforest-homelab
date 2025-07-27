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
  description = "CPU limit for OpenSpeedTest"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for OpenSpeedTest"
  type        = string
  default     = "512Mi"
}

variable "enable_persistence" {
  description = "Enable persistent storage"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Storage size for OpenSpeedTest"
  type        = string
  default     = "10Gi"
}

variable "image_name" {
  description = "Docker image name for OpenSpeedTest"
  type        = string
  default     = "openspeedtest/latest"
}

variable "keep_locally" {
  description = "Keep Docker image locally after destroy"
  type        = bool
  default     = false
}

variable "internal_port" {
  description = "Internal port for OpenSpeedTest container"
  type        = number
  default     = 3000
}

variable "external_port" {
  description = "External port for OpenSpeedTest container"
  type        = number
  default     = 3333
}