variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "service_name" {
  description = "Service name for the volume"
  type        = string
}

variable "volume_name" {
  description = "Volume name (e.g., data, config, logs)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "volume_type" {
  description = "Type of volume (data, config, logs, cache)"
  type        = string
  default     = "data"
  validation {
    condition     = contains(["data", "config", "logs", "cache"], var.volume_type)
    error_message = "Volume type must be one of: data, config, logs, cache."
  }
}

variable "driver_opts" {
  description = "Docker volume driver options"
  type        = map(string)
  default     = {}
}

variable "use_external_storage" {
  description = "Use external storage (Samsung T7 Touch) instead of Docker's internal storage"
  type        = bool
  default     = false
}