variable "namespace" {
  description = "Kubernetes namespace to deploy MCP Gateway"
  type        = string
  default     = "homelab"
}

variable "image_tag" {
  description = "Docker MCP Gateway image tag"
  type        = string
  default     = "latest"
}

variable "gateway_port" {
  description = "Port for MCP Gateway to listen on"
  type        = number
  default     = 8080
}

variable "transport_mode" {
  description = "Transport mode for MCP Gateway (stdio, sse, streaming)"
  type        = string
  default     = "sse"
  
  validation {
    condition     = contains(["stdio", "sse", "streaming"], var.transport_mode)
    error_message = "Transport mode must be one of: stdio, sse, streaming"
  }
}

variable "docker_host" {
  description = "Docker host URL for MCP servers to connect to"
  type        = string
  default     = "tcp://dockerproxy:2375"
}

variable "mcp_servers" {
  description = "Map of MCP servers to enable"
  type = map(object({
    image       = string
    description = string
    environment = optional(map(string), {})
  }))
  default = {
    docker = {
      image       = "mcp/docker"
      description = "Docker MCP server for container management"
      environment = {}
    }
    playwright = {
      image       = "mcp/playwright"
      description = "Playwright MCP server for web automation"
      environment = {}
    }
    fetch = {
      image       = "mcp/fetch"
      description = "Web fetching and content extraction"
      environment = {}
    }
  }
}

variable "enabled_tools" {
  description = "List of MCP tools to enable"
  type        = list(string)
  default     = ["docker", "playwright", "fetch"]
}

variable "security_block_network" {
  description = "Block tools from accessing forbidden network resources"
  type        = bool
  default     = false
}

variable "security_block_secrets" {
  description = "Block secrets from being sent to/from tools"
  type        = bool
  default     = true
}

variable "cors_enabled" {
  description = "Enable CORS for web access"
  type        = bool
  default     = true
}

variable "cors_origins" {
  description = "Allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "resource_limits" {
  description = "Resource limits for MCP Gateway container"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "1000m"
    memory = "2Gi"
  }
}

variable "resource_requests" {
  description = "Resource requests for MCP Gateway container"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "500m"
    memory = "1Gi"
  }
}