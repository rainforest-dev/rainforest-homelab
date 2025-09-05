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

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "homelab"
}

# Docker MCP Gateway specific variables

variable "replicas" {
  description = "Number of Docker MCP Gateway replicas"
  type        = number
  default     = 1
}

variable "docker_image" {
  description = "Docker image for the MCP Gateway container"
  type        = string
  default     = "alpine:3.19"  # Lightweight base image
}

variable "port" {
  description = "Port for Docker MCP Gateway service"
  type        = number
  default     = 8080
}

variable "cpu_limit" {
  description = "CPU limit for Docker MCP Gateway"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for Docker MCP Gateway"
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

variable "docker_timeout" {
  description = "Timeout for Docker operations in seconds"
  type        = number
  default     = 30
}

variable "enable_network_policy" {
  description = "Enable Kubernetes network policy for security"
  type        = bool
  default     = false
}

# Security variables

variable "enable_docker_socket" {
  description = "Enable Docker socket access (required for MCP Docker operations)"
  type        = bool
  default     = true
}

variable "allowed_docker_operations" {
  description = "List of allowed Docker operations for security"
  type        = list(string)
  default = [
    "container.list",
    "container.inspect",
    "container.logs",
    "container.stats",
    "image.list",
    "image.inspect"
  ]
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

# Monitoring and observability

variable "enable_metrics" {
  description = "Enable Prometheus metrics endpoint"
  type        = bool
  default     = false
}

variable "metrics_port" {
  description = "Port for Prometheus metrics"
  type        = number
  default     = 9090
}

variable "enable_health_checks" {
  description = "Enable health check endpoints"
  type        = bool
  default     = true
}