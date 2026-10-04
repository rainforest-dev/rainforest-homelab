variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  type        = string
}

variable "cloudflare_team_name" {
  description = "Cloudflare Zero Trust team name"
  type        = string
}

variable "domain_suffix" {
  description = "Domain suffix for the OAuth worker"
  type        = string
}
variable "enable_memories_mcp" {
  description = "Route memories-mcp.<domain> through the Worker and give it the memories gateway secret"
  type        = bool
  default     = false
}

variable "memories_gateway_secret" {
  description = "Value the Worker sends as x-memories-gateway; must equal the container's MEMORIES_MCP_SECRET"
  type        = string
  default     = null
  sensitive   = true
}
