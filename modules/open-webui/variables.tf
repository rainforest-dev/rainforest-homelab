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

variable "mcpo_enabled" {
  description = "Enable MCPO (Model Context Protocol for Open WebUI) integration"
  type        = bool
  default     = false
}

variable "mcp_servers_config" {
  description = "Configuration for MCP servers in JSON format"
  type = map(object({
    command = string
    args    = list(string)
    type    = string
    env     = optional(map(string), {})
  }))
  default = {}
}

variable "enable_docker_socket" {
  description = "Enable Docker socket access for running MCP services in containers"
  type        = bool
  default     = false
}
