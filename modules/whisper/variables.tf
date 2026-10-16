variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "model_size" {
  description = "Default model: a Whisper size or a key of remote_models"
  type        = string
  default     = "base"
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

variable "memory_limit" {
  description = "Memory limit for Whisper container (e.g. 512Mi, 1Gi)"
  type        = string
  default     = "512Mi"
}
variable "remote_models" {
  description = "Models served outside the container, as name => base URL (e.g. qwen3-asr => http://host.docker.internal:9191)"
  type        = map(string)
  default     = {}
}

variable "remote_api_key" {
  description = "Bearer token sent to remote_models"
  type        = string
  default     = ""
  sensitive   = true
}

variable "remote_fallback_model" {
  description = "Local Whisper model to use when a remote model fails; empty returns the error instead"
  type        = string
  default     = ""
}
