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

variable "replicas" {
  description = "Number of MCPO replicas"
  type        = number
  default     = 1
}

variable "mcpo_image" {
  description = "MCPO Docker image"
  type        = string
  default     = "python:3.11-slim"
}

variable "cpu_limit" {
  description = "CPU limit for MCPO"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for MCPO"
  type        = string
  default     = "512Mi"
}

variable "enable_docker_socket" {
  description = "Enable Docker socket access for MCP_DOCKER"
  type        = bool
  default     = true
}

variable "mcp_servers" {
  description = "List of MCP servers to proxy"
  type = list(object({
    name    = string
    command = string
    args    = list(string)
  }))
  default = [
    {
      name    = "docker"
      command = "docker"
      args    = ["mcp", "gateway", "run"]
    }
  ]
}
