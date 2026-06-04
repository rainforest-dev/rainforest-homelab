variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "homelab"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "obsidian_api_key" {
  description = "API key for Obsidian Local REST API"
  type        = string
  sensitive   = true
}

variable "port" {
  description = "Port for Obsidian MCP SSE server"
  type        = number
  default     = 8100
}

variable "memory_limit" {
  description = "Memory limit for container (e.g., 512Mi, 1Gi)"
  type        = string
  default     = "512Mi"
}

variable "docker_host_address" {
  description = "Address for accessing host services from Docker (use 'host.docker.internal' for Docker Desktop)"
  type        = string
  default     = "host.docker.internal"
}
