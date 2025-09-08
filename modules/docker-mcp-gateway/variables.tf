# Standard module variables following homelab patterns

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

# Docker MCP Gateway specific variables

variable "docker_image" {
  description = "Docker image for the MCP Gateway container"
  type        = string
  default     = "docker/mcp-gateway:latest"  # Use official Docker MCP Gateway image
}

variable "port" {
  description = "Port for Docker MCP Gateway service"
  type        = number
  default     = 3000  # Standard MCP server port
}

variable "memory_limit" {
  description = "Memory limit for Docker MCP Gateway (e.g., 512Mi, 1Gi)"
  type        = string
  default     = "512Mi"
}

variable "log_level" {
  description = "Log level for Docker MCP Gateway"
  type        = string
  default     = "info"
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

# External access variables

variable "enable_cloudflare_tunnel" {
  description = "Enable access via Cloudflare Tunnel"
  type        = bool
  default     = true
}

variable "tunnel_hostname" {
  description = "Hostname for Cloudflare Tunnel access"
  type        = string
  default     = "docker-mcp"
}

variable "domain_suffix" {
  description = "Domain suffix for external access"
  type        = string
  default     = ""
}