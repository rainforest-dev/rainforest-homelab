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

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "homelab"
}

variable "cpu_limit" {
  description = "CPU limit for Open WebUI"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for Open WebUI"
  type        = string
  default     = "512Mi"
}

variable "enable_persistence" {
  description = "Enable persistent storage"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Storage size for Open WebUI"
  type        = string
  default     = "10Gi"
}

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://helm.openwebui.com/"
}

variable "chart_name" {
  description = "Helm chart name"
  type        = string
  default     = "open-webui"
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
  default     = null
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "ollama_enabled" {
  description = "Enable Ollama integration"
  type        = bool
  default     = false
}

variable "ollama_base_url" {
  description = "Ollama base URL for external Ollama instance"
  type        = string
  default     = ""
}

variable "database_url" {
  description = "PostgreSQL database URL for Open WebUI"
  type        = string
  default     = ""
  sensitive   = true
}

variable "deployment_type" {
  description = "Deployment type: 'helm' for Kubernetes Helm chart or 'docker' for Docker container"
  type        = string
  default     = "helm"
  validation {
    condition     = contains(["helm", "docker"], var.deployment_type)
    error_message = "Deployment type must be either 'helm' or 'docker'."
  }
}

variable "whisper_stt_url" {
  description = "Whisper STT API URL for speech-to-text functionality"
  type        = string
  default     = ""
}

variable "domain_suffix" {
  description = "Domain suffix for external access"
  type        = string
  default     = ""
}

