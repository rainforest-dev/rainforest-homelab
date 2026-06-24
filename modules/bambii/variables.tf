variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "dashboard_port" {
  description = "External port for the Hermes dashboard"
  type        = number
  default     = 9119
}

variable "api_port" {
  description = "External port for the Hermes gateway API"
  type        = number
  default     = 8642
}

variable "api_server_key" {
  description = "API server authentication key (min 8 chars). Generate with: openssl rand -hex 32"
  type        = string
  sensitive   = true
}

variable "memory_limit" {
  description = "Memory limit for the container"
  type        = string
  default     = "4096M"
}

variable "use_external_storage" {
  description = "Use external storage for data volume"
  type        = bool
  default     = true
}
