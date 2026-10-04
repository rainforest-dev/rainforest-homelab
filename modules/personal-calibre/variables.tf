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
  description = "Full Docker image reference (e.g. ghcr.io/rainforest-dev/personal-calibre:latest)"
  type        = string

  validation {
    condition     = can(regex("^[^@]+:[^:/@]+$", var.image))
    error_message = "image must be \"repo:tag\" (e.g. ghcr.io/rainforest-dev/personal-calibre:latest); a digest form (repo@sha256:...) or a tag-less reference is not accepted, the module resolves and pins the digest itself."
  }
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

variable "memory_limit" {
  description = "Memory limit for the container (e.g. 512Mi, 1Gi)"
  type        = string
  default     = "512Mi"
}

variable "docker_host" {
  description = "Docker daemon the provider manages; the pre-replace pull targets the same daemon"
  type        = string
  default     = "unix:///var/run/docker.sock"
}
