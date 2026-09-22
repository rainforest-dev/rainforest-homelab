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

variable "image" {
  description = "Full Docker image reference (e.g. ghcr.io/rainforest-dev/personal-memories:latest)"
  type        = string
}

variable "external_port" {
  description = "Host port to expose the app on"
  type        = number
  default     = 3004
}

variable "data_dir" {
  description = "Host path to the memories data directory (line/, slack/, photos/, timeline.json)"
  type        = string
}

variable "photos_library_path" {
  description = "Host path to the macOS Photos library that timeline.json media paths point into"
  type        = string
}

variable "node_env" {
  description = "NODE_ENV value passed to the container"
  type        = string
  default     = "production"
}

variable "memory_limit" {
  description = "Memory limit for the container (e.g. 256Mi, 512Mi)"
  type        = string
  default     = "512Mi"
}
