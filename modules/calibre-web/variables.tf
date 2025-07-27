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
  description = "CPU limit for Calibre Web"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for Calibre Web"
  type        = string
  default     = "512Mi"
}

variable "enable_persistence" {
  description = "Enable persistent storage"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Storage size for Calibre Web config"
  type        = string
  default     = "10Gi"
}

variable "image_name" {
  description = "Docker image name for Calibre Web"
  type        = string
  default     = "lscr.io/linuxserver/calibre-web"
}

variable "image_tag" {
  description = "Docker image tag for Calibre Web"
  type        = string
  default     = "latest"
}

variable "internal_port" {
  description = "Internal port for Calibre Web container"
  type        = number
  default     = 8083
}

variable "external_port" {
  description = "External port for Calibre Web container"
  type        = number
  default     = 8083
}

variable "puid" {
  description = "Process User ID for file permissions"
  type        = string
  default     = "1000"
}

variable "pgid" {
  description = "Process Group ID for file permissions"
  type        = string
  default     = "1000"
}

variable "timezone" {
  description = "Timezone for the container"
  type        = string
  default     = "Asia/Taipei"
}

variable "books_path" {
  description = "Host path to books library"
  type        = string
  default     = "/Users/rainforest/Library/CloudStorage/SynologyDrive-CalibreLibrary"
}