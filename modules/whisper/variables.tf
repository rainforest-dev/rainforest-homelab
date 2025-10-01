variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "model_size" {
  description = "Whisper model size (tiny, base, small, medium, large, large-v2, large-v3)"
  type        = string
  default     = "base"

  validation {
    condition     = contains(["tiny", "base", "small", "medium", "large", "large-v2", "large-v3"], var.model_size)
    error_message = "Model size must be one of: tiny, base, small, medium, large, large-v2, large-v3"
  }
}

variable "external_port" {
  description = "External port for Whisper API"
  type        = number
  default     = 9000
}

variable "enable_gpu" {
  description = "Enable GPU acceleration (requires NVIDIA GPU and drivers)"
  type        = bool
  default     = false
}

variable "use_external_storage" {
  description = "Use external storage for model cache"
  type        = bool
  default     = true
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "domain_suffix" {
  description = "Domain suffix for external access"
  type        = string
  default     = ""
}