variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "comfyui_host" {
  description = "ComfyUI backend URL. Use host.docker.internal for Mac Mini, or PC LAN IP."
  type        = string
  default     = "http://host.docker.internal:8000"
}

variable "api_key" {
  description = "Bearer token required on Authorization header. Empty = no auth."
  type        = string
  default     = ""
  sensitive   = true
}

variable "external_port" {
  description = "Host port the adapter listens on"
  type        = number
  default     = 7860
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "domain_suffix" {
  description = "Domain suffix for external access URL output"
  type        = string
  default     = ""
}
