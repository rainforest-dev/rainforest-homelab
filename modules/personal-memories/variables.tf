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
  default     = 8085
}

variable "memories_data_path" {
  description = "Host path to the memories data directory (timeline.json and the Slack export). Mounted read-only at this same path inside the container, because timeline.json records absolute host paths."
  type        = string
}

variable "photos_library_path" {
  description = "Host path holding the photo files that timeline.json points at, usually the Photos library. Mounted read-only at this same path inside the container."
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
  default     = "256Mi"
}
