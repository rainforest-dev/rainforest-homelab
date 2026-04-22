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
  description = "Full Docker image reference (e.g. ghcr.io/rainforest-dev/rainforest-monorepo/personal-calibre:latest)"
  type        = string
}

variable "external_port" {
  description = "Host port to expose the app on"
  type        = number
  default     = 8082
}

variable "calibre_library_path" {
  description = "Host path to the Calibre library (contains metadata.db and book files)"
  type        = string
}

variable "node_env" {
  description = "NODE_ENV value passed to the container"
  type        = string
  default     = "production"
}
