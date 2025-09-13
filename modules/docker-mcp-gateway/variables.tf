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
  default     = "docker/mcp-gateway:latest" # Use latest as 0.1.0 tag doesn't exist yet
}

variable "port" {
  description = "Port for Docker MCP Gateway service"
  type        = number
  default     = 3100 # Avoid conflicts with common dev servers on 3000
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

variable "docker_host_address" {
  description = "Address for accessing Docker containers from Cloudflare Tunnel (use 'host.docker.internal' for Docker Desktop, 'localhost' for Linux)"
  type        = string
  default     = "host.docker.internal"  # Default for Docker Desktop
}

# Security Notes for Docker MCP Gateway:
# This module requires Docker socket access which provides significant privileges.
# Security considerations:
# 1. Container management capabilities (create, modify, delete containers)
# 2. Image operations (pull, build, push images)  
# 3. Potential host filesystem access through volume mounts
# 4. Privilege escalation possibilities
# 
# Mitigations implemented:
# - OAuth authentication via Cloudflare Zero Trust (when enabled)
# - Localhost-only port binding (127.0.0.1)
# - Resource limits (memory constraints)
# - Health checks and restart policies
# - Conditional configuration mounting
# 
# Additional recommended mitigations:
# - Deploy only in trusted environments
# - Enable comprehensive logging and monitoring
# - Use network segmentation
# - Regular security audits of container activities
# - Consider Docker-in-Docker (DinD) for enhanced isolation
