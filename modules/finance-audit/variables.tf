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
  description = "Docker image reference. Built locally from rainforest-finance/apps/finance-audit and never pushed, so it must already exist in the local daemon before apply."
  type        = string
  default     = "finance-audit:local"
}

variable "external_port" {
  description = "Host port to expose the app on"
  type        = number
  default     = 8085
}

variable "artifacts_path" {
  description = "Host path to the rainforest-finance artifacts directory (mounted read-only at /srv/artifacts and served as /artifacts/*)"
  type        = string

  validation {
    condition     = can(regex("^/", var.artifacts_path))
    error_message = "artifacts_path must be an absolute host path — a relative or empty path makes Docker create a named volume instead of a bind mount, and the site would silently serve nothing."
  }
}

variable "memory_limit" {
  description = "Memory limit for the container (e.g. 128Mi, 256Mi). Static nginx — 128Mi is ample."
  type        = string
  default     = "128Mi"
}
